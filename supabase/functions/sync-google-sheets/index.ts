// @ts-nocheck
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

class GeminiService {
    private apiKey: string;
    private baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

    constructor(apiKey: string) {
        this.apiKey = apiKey;
    }

    async generateEmbedding(text: string): Promise<number[] | null> {
        try {
            const response = await fetch(
                `${this.baseUrl}/gemini-embedding-001:embedContent?key=${this.apiKey}`,
                {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        content: { parts: [{ text: text }] },
                    }),
                }
            );
            if (!response.ok) {
                console.error(`Gemini API Error (Key ...${this.apiKey.slice(-4)}):`, await response.text());
                return null;
            }
            const data = await response.json();
            return data.embedding?.values ?? null;
        } catch (error) {
            console.error('Error generating embedding:', error);
            return null;
        }
    }
}

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

        const GOOGLE_SHEET_ID = Deno.env.get('GOOGLE_SHEET_ID')
        const GOOGLE_API_KEY = Deno.env.get('GOOGLE_API_KEY')
        const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
        const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

        // ✅ ใช้ GEMINI_EMBEDDING_KEY เท่านั้น
        const embeddingKey = Deno.env.get('GEMINI_EMBEDDING_KEY');

        if (!embeddingKey) {
            console.error('❌ NO GEMINI_EMBEDDING_KEY FOUND - Embeddings will be NULL!');
        } else {
            console.log('✓ Using GEMINI_EMBEDDING_KEY for embeddings');
        }

        if (!GOOGLE_SHEET_ID || !GOOGLE_API_KEY) {
            throw new Error('Missing Google Sheets credentials')
        }

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

        const [headers, ...dataRows] = rows

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

        if (embeddingKey) {
            console.log('Using GEMINI_EMBEDDING_KEY (Model: gemini-embedding-001)')
            const geminiService = new GeminiService(embeddingKey);

            let successCount = 0;
            for (let i = 0; i < records.length; i++) {
                const record = records[i];
                const textToEmbed = [
                    `Category: ${record.category}`,
                    `Subcategory: ${record.subcategory}`,
                    `Symptom: ${record.symptom_description}`,
                    `Observation: ${record.observation}`,
                    `Possible Causes: ${record.possible_causes}`,
                    `Solution: ${record.solution}`,
                ].join('\n').trim();

                const embedding = await geminiService.generateEmbedding(textToEmbed);
                if (embedding) {
                    records[i].embedding = embedding;
                    successCount++;
                }

                if (i % 5 === 0) await new Promise(r => setTimeout(r, 200));
            }
            console.log(`✓ Embedding done: ${successCount}/${records.length} records got embeddings`)
        } else {
            console.warn('NO GEMINI_EMBEDDING_KEY FOUND. Skipping embedding generation.');
        }

        console.log('Deleting old Google Sheets data...')
        await fetch(
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
                message: `Synced ${insertedCount} records`,
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