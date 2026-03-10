// @ts-nocheck
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const GEMINI_EMBED_LIMIT = 1500;
const EMBED_KEY_INDEX = 21; // Embedding key index in api_usage_logs

// บันทึก embedding usage หลัง sync เสร็จ
async function logEmbeddingUsage(supabase: any, usedCount: number) {
    try {
        const { data: prevLog } = await supabase
            .from('api_usage_logs')
            .select('requests_remaining, timestamp')
            .eq('api_key_index', EMBED_KEY_INDEX)
            .order('timestamp', { ascending: false })
            .limit(1);

        const now = new Date();
        let prevRemaining = GEMINI_EMBED_LIMIT;
        if (prevLog && prevLog.length > 0) {
            const prevDate = new Date(prevLog[0].timestamp);
            const isSameDay = prevDate.toDateString() === now.toDateString();
            prevRemaining = isSameDay ? (prevLog[0].requests_remaining ?? GEMINI_EMBED_LIMIT) : GEMINI_EMBED_LIMIT;
        }

        const newRemaining = Math.max(0, prevRemaining - usedCount);

        const resetDate = new Date(now);
        resetDate.setUTCHours(8, 0, 0, 0);
        if (now.getUTCHours() >= 8) resetDate.setUTCDate(resetDate.getUTCDate() + 1);
        const resetTimeStr = resetDate.toISOString();

        await supabase.from('api_usage_logs').insert({
            api_key_index: EMBED_KEY_INDEX,
            requests_remaining: newRemaining,
            requests_limit: GEMINI_EMBED_LIMIT,
            tokens_remaining: null,
            tokens_limit: null,
            reset_time: resetTimeStr,
            timestamp: now.toISOString(),
        });

        console.log(`Logged embedding usage: ${newRemaining}/${GEMINI_EMBED_LIMIT} remaining (used ${usedCount} this sync)`);
    } catch (e) {
        console.error('logEmbeddingUsage error:', e);
    }
}

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
                    body: JSON.stringify({ content: { parts: [{ text }] } }),
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
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

    try {
        console.log('Starting General Information sync...');

        const GOOGLE_SHEET_ID = Deno.env.get('GOOGLE_SHEET_ID');
        const GOOGLE_API_KEY = Deno.env.get('GOOGLE_API_KEY');
        const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
        const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
        const embeddingKey = Deno.env.get('GEMINI_EMBEDDING_KEY');

        const supabase = createClient(SUPABASE_URL!, SUPABASE_SERVICE_KEY!);

        if (!embeddingKey) {
            console.error('NO GEMINI_EMBEDDING_KEY FOUND - Embeddings will be NULL!');
        } else {
            console.log('✓ Using GEMINI_EMBEDDING_KEY for embeddings');
        }

        if (!GOOGLE_SHEET_ID || !GOOGLE_API_KEY) throw new Error('Missing Google Sheets credentials');

        // ดึงข้อมูลจาก tab general_information
        const sheetName = 'general_information';
        const sheetUrl = `https://sheets.googleapis.com/v4/spreadsheets/${GOOGLE_SHEET_ID}/values/${encodeURIComponent(sheetName)}?key=${GOOGLE_API_KEY}&valueRenderOption=FORMATTED_VALUE`;

        const response = await fetch(sheetUrl);
        if (!response.ok) throw new Error(`Google Sheets API Error: ${await response.text()}`);

        const data = await response.json();
        const rows = data.values;
        if (!rows || rows.length === 0) throw new Error('No data found in sheet');
        console.log(`Found ${rows.length} rows`);

        // Skip header row
        const [, ...dataRows] = rows;
        const cleanText = (text: any) => {
            if (!text) return '';
            return String(text).replace(/\\n/g, ' / ').replace(/\s+/g, ' ').trim();
        };

        let records = dataRows
            .filter((row: any[]) => row.length > 0 && row[0] && String(row[0]).trim())
            .map((row: any[]) => ({
                title: cleanText(row[0]),
                content: cleanText(row[1]),
                sheet_source: 'google_sheets',
                search_keywords: [row[0], row[1]]
                    .filter(Boolean).map(t => cleanText(t)).join(' '),
                embedding: null as number[] | null,
            }));

        console.log(`Processed ${records.length} records. Generating embeddings...`);

        // Generate embeddings
        let successCount = 0;
        if (embeddingKey) {
            const geminiService = new GeminiService(embeddingKey);
            for (let i = 0; i < records.length; i++) {
                const textToEmbed = [
                    `หัวข้อ: ${records[i].title}`,
                    `เนื้อหา: ${records[i].content}`,
                ].join('\n').trim();

                const embedding = await geminiService.generateEmbedding(textToEmbed);
                if (embedding) { records[i].embedding = embedding; successCount++; }
                if (i % 5 === 0) await new Promise(r => setTimeout(r, 200));
            }
            console.log(`✓ Embedding done: ${successCount}/${records.length} records`);

            await logEmbeddingUsage(supabase, successCount);
        } else {
            console.warn('NO GEMINI_EMBEDDING_KEY FOUND. Skipping embedding generation.');
        }

        // ลบข้อมูลเก่าจาก google_sheets
        console.log('Deleting old general_information data...');
        await fetch(
            `${SUPABASE_URL}/rest/v1/general_information?sheet_source=eq.google_sheets`,
            {
                method: 'DELETE',
                headers: {
                    'apikey': SUPABASE_SERVICE_KEY!,
                    'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
                    'Content-Type': 'application/json',
                    'Prefer': 'return=minimal',
                },
            }
        );

        // Insert ข้อมูลใหม่
        let insertedCount = 0;
        const batchSize = 50;
        for (let i = 0; i < records.length; i += batchSize) {
            const batch = records.slice(i, i + batchSize);
            const insertResponse = await fetch(
                `${SUPABASE_URL}/rest/v1/general_information`,
                {
                    method: 'POST',
                    headers: {
                        'apikey': SUPABASE_SERVICE_KEY!,
                        'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
                        'Content-Type': 'application/json',
                        'Prefer': 'return=representation',
                    },
                    body: JSON.stringify(batch),
                }
            );
            if (!insertResponse.ok) {
                console.error(`Batch ${i}-${i + batchSize} error:`, await insertResponse.text());
            } else {
                const insertedData = await insertResponse.json();
                insertedCount += insertedData.length;
                console.log(`Inserted batch: ${insertedData.length} records`);
            }
        }

        console.log(`✓ General Information sync complete! ${insertedCount} records`);
        return new Response(
            JSON.stringify({ success: true, message: `Synced ${insertedCount} general information records`, records: insertedCount }),
            { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
    } catch (error: any) {
        console.error('Error:', error);
        return new Response(
            JSON.stringify({ success: false, error: error.message }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
    }
});
