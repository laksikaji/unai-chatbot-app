// @ts-nocheck
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

// --- GEMINI SERVICE CLASS (With Multiple Keys Support) ---
class GeminiService {
    private apiKeys: string[];
    // เปลี่ยนเป็น v1 (Stable)
    private baseUrl = 'https://generativelanguage.googleapis.com/v1/models';

    constructor(apiKeys: string[]) {
        this.apiKeys = apiKeys;
    }

    private getRandomKey(): string {
        return this.apiKeys[Math.floor(Math.random() * this.apiKeys.length)];
    }

    // Generate Embedding
    async generateEmbedding(text: string): Promise<number[] | null> {
        const apiKey = this.getRandomKey();
        try {
            // ใช้ model: embedding-001 (Stable)
            const response = await fetch(
                `${this.baseUrl}/embedding-001:embedContent?key=${apiKey}`,
                {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        model: 'models/embedding-001',
                        content: { parts: [{ text: text }] },
                    }),
                }
            );

            if (!response.ok) {
                console.error(`Gemini API Error (Key ends with ...${apiKey.slice(-4)}): ${response.status} ${response.statusText}`, await response.text());
                return null;
            }
            const data = await response.json();
            return data.embedding.values;
        } catch (error) {
            console.error('Error generating embedding:', error);
            return null;
        }
    }
}
// -------------------------------------------------------------

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req: Request) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        console.log('Starting Google Sheets sync...')

        // @ts-ignore
        const GOOGLE_SHEET_ID = Deno.env.get('GOOGLE_SHEET_ID')
        // @ts-ignore
        const GOOGLE_API_KEY = Deno.env.get('GOOGLE_API_KEY')
        // @ts-ignore
        const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
        // @ts-ignore
        const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

        // Load Multiple Gemini Keys
        const geminiKeys: string[] = [];
        for (let i = 1; i <= 5; i++) {
            // @ts-ignore
            const key = Deno.env.get(`GEMINI_API_KEY_${i}`);
            if (key) geminiKeys.push(key);
        }
        // Fallback
        // @ts-ignore
        const singleGeminiKey = Deno.env.get('GEMINI_API_KEY');
        if (singleGeminiKey && geminiKeys.length === 0) geminiKeys.push(singleGeminiKey);

        if (!GOOGLE_SHEET_ID || !GOOGLE_API_KEY) {
            throw new Error('Missing Google Sheets credentials')
        }

        // ดึงข้อมูลจาก Google Sheets
        const sheetName = 'troubleshooting_guide'
        const sheetUrl = `https://sheets.googleapis.com/v4/spreadsheets/${GOOGLE_SHEET_ID}/values/${encodeURIComponent(sheetName)}?key=${GOOGLE_API_KEY}&valueRenderOption=FORMATTED_VALUE`

        console.log('Fetching from Google Sheets...')
        const response = await fetch(sheetUrl)

        if (!response.ok) {
            const error = await response.text()
            throw new Error(`Google Sheets API Error: ${error}`)
        }

        const data = await response.json()
        const rows = data.values

        if (!rows || rows.length === 0) {
            throw new Error('No data found in sheet')
        }

        console.log(`Found ${rows.length} rows`)

        // แยก Header และ Data
        const [headers, ...dataRows] = rows

        // แปลงเป็น JSON
        const cleanText = (text: any) => {
            if (!text) return ''
            return String(text).replace(/\n/g, ' / ').replace(/\s+/g, ' ').trim()
        }

        let records = dataRows
            .filter((row: any[]) => row.length > 0 && row[0] && String(row[0]).trim())
            .map((row: any[]) => ({
                category: cleanText(row[0]),
                subcategory: cleanText(row[1]),
                symptom_description: cleanText(row[2]),
                observation: cleanText(row[3]),
                initial_check: cleanText(row[4]),
                possible_causes: cleanText(row[5]),
                solution: cleanText(row[6]),
                responsible_party: cleanText(row[7]),
                sheet_source: 'google_sheets',
                search_keywords: [row[0], row[1], row[2], row[3], row[4]]
                    .filter(Boolean)
                    .map(t => cleanText(t))
                    .join(' '),
                embedding: null as number[] | null
            }))

        console.log(`Processed ${records.length} records. Generating embeddings...`)

        // --- Generate Embeddings ---
        if (geminiKeys.length > 0) {
            console.log(`Using ${geminiKeys.length} Gemini API Keys for embedding generation (Model: embedding-001).`);
            const geminiService = new GeminiService(geminiKeys);

            for (let i = 0; i < records.length; i++) {
                const record = records[i];
                const textToEmbed = `
                    Category: ${record.category}
                    Subcategory: ${record.subcategory}
                    Symptom: ${record.symptom_description}
                    Observation: ${record.observation}
                    Possible Causes: ${record.possible_causes}
                    Solution: ${record.solution}
                `.trim();

                const embedding = await geminiService.generateEmbedding(textToEmbed);
                if (embedding) {
                    records[i].embedding = embedding;
                }

                // Rate limit (delay)
                if (i % 5 === 0) await new Promise(r => setTimeout(r, 100));
            }
        } else {
            console.warn('NO GEMINI_API_KEY FOUND. Skipping embedding generation.');
        }

        // Deleting old data & Insert new data...
        // (ส่วนที่เหลือเหมือนเดิม)
        console.log('Deleting old Google Sheets data...')
        const deleteResponse = await fetch(
            `${SUPABASE_URL}/rest/v1/troubleshooting_guide?sheet_source=eq.google_sheets`,
            {
                method: 'DELETE',
                headers: {
                    'apikey': SUPABASE_SERVICE_KEY!,
                    'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
                    'Content-Type': 'application/json',
                    'Prefer': 'return=minimal'
                }
            }
        )

        if (!deleteResponse.ok) console.warn('Delete warning:', await deleteResponse.text())
        else console.log('✓ Old Google Sheets data deleted')

        console.log('Inserting new data...')

        let insertedCount = 0
        const batchSize = 50

        for (let i = 0; i < records.length; i += batchSize) {
            const batch = records.slice(i, i + batchSize)
            const insertResponse = await fetch(
                `${SUPABASE_URL}/rest/v1/troubleshooting_guide`,
                {
                    method: 'POST',
                    headers: {
                        'apikey': SUPABASE_SERVICE_KEY!,
                        'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
                        'Content-Type': 'application/json',
                        'Prefer': 'return=representation'
                    },
                    body: JSON.stringify(batch)
                }
            )

            if (!insertResponse.ok) {
                console.error(`Batch ${i}-${i + batchSize} error:`, await insertResponse.text())
            } else {
                const insertedData = await insertResponse.json()
                insertedCount += insertedData.length
                console.log(`Inserted batch ${i}-${i + batchSize}: ${insertedData.length} records`)
            }
        }

        console.log(`✓ Sync complete! ${insertedCount} records from Google Sheets`)

        return new Response(
            JSON.stringify({
                success: true,
                message: `Synced ${insertedCount} records (Model: embedding-001)`,
                records: insertedCount
            }),
            { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )

    } catch (error: any) {
        console.error('Error:', error)
        return new Response(
            JSON.stringify({ success: false, error: error.message }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})