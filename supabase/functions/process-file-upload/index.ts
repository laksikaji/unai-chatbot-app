// @ts-nocheck
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import * as XLSX from 'https://esm.sh/xlsx@0.18.5'

const GEMINI_EMBED_LIMIT = 1500;
const EMBED_KEY_INDEX = 21; // Embedding key index in api_usage_logs

// บันทึก embedding usage หลัง upload เสร็จ (1 log ต่อการ upload)
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

        console.log(`Logged embedding usage: ${newRemaining}/${GEMINI_EMBED_LIMIT} remaining (used ${usedCount} this upload)`);
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
                console.error(`Gemini Embedding API Error (Key ...${this.apiKey.slice(-4)}):`, await response.text());
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

serve(async (req: any) => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

    try {
        const { fileName } = await req.json();
        console.log('=== PROCESSING FILE ===');
        console.log('File name:', fileName);

        const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
        const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
        const supabase = createClient(supabaseUrl, supabaseKey);

        const embeddingKey = Deno.env.get('GEMINI_EMBEDDING_KEY');
        if (!embeddingKey) {
            console.warn('WARNING: NO GEMINI_EMBEDDING_KEY found. Embeddings will not be generated.');
        } else {
            console.log('✓ Using GEMINI_EMBEDDING_KEY for embeddings');
        }

        const geminiService = embeddingKey ? new GeminiService(embeddingKey) : null;

        const { data: fileData, error: downloadError } = await supabase.storage
            .from('admin-uploads').download(fileName);
        if (downloadError) throw downloadError;
        console.log('✓ File downloaded successfully');

        const isExcel = fileName.toLowerCase().endsWith('.xlsx') || fileName.toLowerCase().endsWith('.xls');
        const isCSV = fileName.toLowerCase().endsWith('.csv');
        if (!isExcel && !isCSV) throw new Error('Unsupported file type. Please upload CSV or Excel (.xlsx) files only.');

        let headers: string[] = [];
        let dataRows: string[][] = [];

        if (isExcel) {
            console.log('Parsing Excel file...');
            const arrayBuffer = await fileData.arrayBuffer();
            const workbook = XLSX.read(arrayBuffer, { type: 'array' });
            const sheetName = workbook.SheetNames[0];
            const worksheet = workbook.Sheets[sheetName];
            const data = XLSX.utils.sheet_to_json(worksheet, { header: 1, defval: '' }) as string[][];
            if (data.length < 2) throw new Error('Excel file is empty');
            headers = data[0].map((h: any) => String(h).trim());
            dataRows = data.slice(1).filter((row: any[]) => row.some(cell => cell && String(cell).trim()));
        } else {
            console.log('Parsing CSV file...');
            const text = await fileData.text();
            const lines = text.split('\n').filter((line: string) => line.trim());
            if (lines.length < 2) throw new Error('CSV file is empty');

            const parseCSVRow = (row: string): string[] => {
                const result: string[] = [];
                let current = '';
                let inQuotes = false;
                for (let i = 0; i < row.length; i++) {
                    const char = row[i];
                    if (char === '"') inQuotes = !inQuotes;
                    else if (char === ',' && !inQuotes) {
                        result.push(current.trim().replace(/^["']|["']$/g, ''));
                        current = '';
                    } else current += char;
                }
                result.push(current.trim().replace(/^["']|["']$/g, ''));
                return result;
            };

            headers = parseCSVRow(lines[0]);
            dataRows = lines.slice(1).map((line: string) => parseCSVRow(line));
        }

        console.log('Headers found:', JSON.stringify(headers));

        const normalizeHeader = (header: string) => String(header).toLowerCase().trim().replace(/\s+/g, ' ');
        const headerMap: { [key: string]: number } = {};
        headers.forEach((h, i) => headerMap[normalizeHeader(h)] = i);

        const getValueByHeaders = (values: string[], possibleHeaders: string[]) => {
            for (const h of possibleHeaders) {
                const idx = headerMap[normalizeHeader(h)];
                if (idx !== undefined && values[idx]) return String(values[idx]).trim();
            }
            return '';
        };

        const recordsToProcess = dataRows.map((values) => {
            const record: any = {
                category: getValueByHeaders(values, ['category', 'หมวดหมู่', 'ประเภทหลัก']),
                subcategory: getValueByHeaders(values, ['subcategory', 'หมวดหมู่ย่อย', 'หมวดหมู่ ย่อย', 'ประเภท']),
                symptom_description: getValueByHeaders(values, ['symptom', 'symptom_description', 'อาการ']),
                observation: getValueByHeaders(values, ['observation', 'ข้อสังเกต', 'ข้อสังเกตุ', 'สังเกต', 'สังเกตุ']),
                initial_check: getValueByHeaders(values, ['initial check', 'initial_check', 'ตรวจสอบเบื้องต้น']),
                possible_causes: getValueByHeaders(values, ['possible causes', 'possible_causes', 'สาเหตุ', 'สาเหตุที่อาจเป็นไปได้']),
                solution: getValueByHeaders(values, ['solution', 'วิธีแก้']),
                responsible_party: getValueByHeaders(values, ['responsible', 'responsible_party', 'ผู้รับผิดชอบ', 'ผู้แก้ปัญหาเบื้องต้น']),
                sheet_source: 'admin_upload',
                search_keywords: '',
            };

            record.embeddingContent = [
                `หมวดหมู่: ${record.category}`,
                `หมวดหมู่ย่อย: ${record.subcategory}`,
                `อาการ: ${record.symptom_description}`,
                `สาเหตุ: ${record.possible_causes}`,
                `วิธีแก้: ${record.solution}`,
            ].join('\n');

            record.search_keywords = [record.category, record.subcategory, record.symptom_description]
                .filter(Boolean).join(' ');

            return record;
        }).filter(r => r.category || r.symptom_description);

        // 1. Fetch existing records to check for exact duplicates
        const { data: existingRecords, error: fetchError } = await supabase
            .from('troubleshooting_guide')
            .select('category, subcategory, symptom_description, possible_causes, solution');

        if (fetchError) {
            console.error('Error fetching existing records:', fetchError);
            throw fetchError;
        }

        const duplicateRecords: any[] = [];
        const newRecordsToProcess: any[] = [];

        // 2. Separate duplicates and new records
        for (const record of recordsToProcess) {
            const isDuplicate = existingRecords && existingRecords.some((ex: any) =>
                (String(ex.category || '').trim() === String(record.category || '').trim()) &&
                (String(ex.subcategory || '').trim() === String(record.subcategory || '').trim()) &&
                (String(ex.symptom_description || '').trim() === String(record.symptom_description || '').trim()) &&
                (String(ex.possible_causes || '').trim() === String(record.possible_causes || '').trim()) &&
                (String(ex.solution || '').trim() === String(record.solution || '').trim())
            );

            if (isDuplicate) {
                const { embeddingContent, search_keywords, sheet_source, ...safeRecord } = record;
                duplicateRecords.push(safeRecord);
            } else {
                newRecordsToProcess.push(record);
                if (existingRecords) {
                    existingRecords.push(record); // Prevent duplicates within the same uploaded file
                }
            }
        }

        console.log(`Found ${duplicateRecords.length} duplicates, ${newRecordsToProcess.length} new records to process.`);

        console.log(`=== GENERATING EMBEDDINGS (${newRecordsToProcess.length} records) ===`);

        const recordsWithEmbeddings: any[] = [];
        let successCount = 0;
        const BATCH_SIZE = 5;

        for (let i = 0; i < newRecordsToProcess.length; i += BATCH_SIZE) {
            const batch = newRecordsToProcess.slice(i, i + BATCH_SIZE);
            console.log(`Processing batch ${Math.floor(i / BATCH_SIZE) + 1}/${Math.ceil(newRecordsToProcess.length / BATCH_SIZE)}...`);

            await Promise.all(batch.map(async (record) => {
                let embedding = null;
                if (geminiService && record.embeddingContent) {
                    await new Promise(resolve => setTimeout(resolve, 100 * (i % 3)));
                    embedding = await geminiService.generateEmbedding(record.embeddingContent);
                    if (embedding) successCount++;
                }
                const { embeddingContent, ...dbRecord } = record;
                recordsWithEmbeddings.push({ ...dbRecord, embedding });
            }));
        }

        console.log(`Generated embeddings for ${successCount}/${recordsWithEmbeddings.length} records`);

        if (geminiService) {
            await logEmbeddingUsage(supabase, successCount);
        }

        if (recordsWithEmbeddings.length > 0) {
            const { error: insertError } = await supabase
                .from('troubleshooting_guide').insert(recordsWithEmbeddings);
            if (insertError) throw insertError;
        }

        await supabase.storage.from('admin-uploads').remove([fileName]);

        const totalProcessed = recordsWithEmbeddings.length;
        const totalDuplicated = duplicateRecords.length;

        if (totalProcessed === 0 && totalDuplicated === 0) {
            throw new Error('No valid records found in the uploaded file.');
        }

        let responseMessage = '';
        if (totalProcessed > 0 && totalDuplicated > 0) {
            responseMessage = `Successfully added ${totalProcessed} records, found ${totalDuplicated} exact duplicates.`;
        } else if (totalProcessed > 0 && totalDuplicated === 0) {
            responseMessage = `Successfully added ${totalProcessed} records.`;
        } else if (totalProcessed === 0 && totalDuplicated > 0) {
            responseMessage = `All ${totalDuplicated} records are exact duplicates (No new records added).`;
        }

        return new Response(
            JSON.stringify({
                success: true,
                inserted_count: totalProcessed,
                duplicated_count: totalDuplicated,
                duplicated_rows: duplicateRecords,
                message: responseMessage
            }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
    } catch (error: any) {
        console.error('ERROR:', error);
        return new Response(
            JSON.stringify({ success: false, error: error.message }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
    }
});