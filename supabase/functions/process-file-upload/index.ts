// @ts-nocheck
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import * as XLSX from 'https://esm.sh/xlsx@0.18.5'

// --- GEMINI SERVICE CLASS (With Multiple Keys Support) ---
class GeminiService {
    private apiKeys: string[];
    private baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

    constructor(apiKeys: string[]) {
        this.apiKeys = apiKeys;
    }

    private getRandomKey(): string {
        return this.apiKeys[Math.floor(Math.random() * this.apiKeys.length)];
    }

    async generateEmbedding(text: string): Promise<number[] | null> {
        const apiKey = this.getRandomKey();
        try {
            const response = await fetch(
                `${this.baseUrl}/text-embedding-004:embedContent?key=${apiKey}`,
                {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        model: 'models/text-embedding-004',
                        content: { parts: [{ text: text }] },
                    }),
                }
            );
            if (!response.ok) {
                console.error(`Gemini Embedding API Error (Key ends with ...${apiKey.slice(-4)}):`, await response.text());
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
// ----------------------------

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req: any) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const { fileName } = await req.json()

        console.log('=== PROCESSING FILE ===')
        console.log('File name:', fileName)

        const supabaseUrl = Deno.env.get('SUPABASE_URL')!
        const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
        const supabase = createClient(supabaseUrl, supabaseKey)

        // Load Multiple Gemini Keys
        const geminiKeys: string[] = [];
        for (let i = 1; i <= 5; i++) {
            const key = Deno.env.get(`GEMINI_API_KEY_${i}`);
            if (key) geminiKeys.push(key);
        }
        // Fallback to single key if multiple not found
        const singleGeminiKey = Deno.env.get('GEMINI_API_KEY');
        if (singleGeminiKey && geminiKeys.length === 0) geminiKeys.push(singleGeminiKey);

        if (geminiKeys.length === 0) {
            console.warn('WARNING: NO GEMINI_API_KEY found (Checked _1 to _5). Embeddings will not be generated.')
        } else {
            console.log(`Using ${geminiKeys.length} Gemini API Keys.`)
        }

        const geminiService = geminiKeys.length > 0 ? new GeminiService(geminiKeys) : null

        const { data: fileData, error: downloadError } = await supabase.storage
            .from('admin-uploads')
            .download(fileName)

        if (downloadError) throw downloadError

        console.log('✓ File downloaded successfully')

        const isExcel = fileName.toLowerCase().endsWith('.xlsx') || fileName.toLowerCase().endsWith('.xls')
        const isCSV = fileName.toLowerCase().endsWith('.csv')

        if (!isExcel && !isCSV) {
            throw new Error('Unsupported file type. Please upload CSV or Excel (.xlsx) files only.')
        }

        let headers: string[] = []
        let dataRows: string[][] = []

        if (isExcel) {
            console.log('Parsing Excel file...')
            const arrayBuffer = await fileData.arrayBuffer()
            const workbook = XLSX.read(arrayBuffer, { type: 'array' })
            const sheetName = workbook.SheetNames[0]
            const worksheet = workbook.Sheets[sheetName]
            const data = XLSX.utils.sheet_to_json(worksheet, { header: 1, defval: '' }) as string[][]

            if (data.length < 2) throw new Error('Excel file is empty')

            headers = data[0].map((h: any) => String(h).trim())
            dataRows = data.slice(1).filter((row: any[]) => row.some(cell => cell && String(cell).trim()))

        } else {
            console.log('Parsing CSV file...')
            const text = await fileData.text()
            const lines = text.split('\n').filter((line: string) => line.trim())

            if (lines.length < 2) throw new Error('CSV file is empty')

            const parseCSVRow = (row: string): string[] => {
                const result: string[] = []
                let current = ''
                let inQuotes = false
                for (let i = 0; i < row.length; i++) {
                    const char = row[i]
                    if (char === '"') inQuotes = !inQuotes
                    else if (char === ',' && !inQuotes) {
                        result.push(current.trim().replace(/^["']|["']$/g, ''))
                        current = ''
                    } else current += char
                }
                result.push(current.trim().replace(/^["']|["']$/g, ''))
                return result
            }

            headers = parseCSVRow(lines[0])
            dataRows = lines.slice(1).map((line: string) => parseCSVRow(line))
        }

        const normalizeHeader = (header: string) => String(header).toLowerCase().trim().replace(/\s+/g, ' ')
        const headerMap: { [key: string]: number } = {}
        headers.forEach((h, i) => headerMap[normalizeHeader(h)] = i)

        const getValueByHeaders = (values: string[], possibleHeaders: string[]) => {
            for (const h of possibleHeaders) {
                const idx = headerMap[normalizeHeader(h)]
                if (idx !== undefined && values[idx]) return String(values[idx]).trim()
            }
            return ''
        }

        const recordsToProcess = dataRows.map((values) => {
            const record: any = {
                category: getValueByHeaders(values, ['category', 'หมวดหมู่', 'ประเภทหลัก']),
                subcategory: getValueByHeaders(values, ['subcategory', 'หมวดหมู่ย่อย', 'หมวดหมู่ ย่อย', 'ประเภท']),
                symptom_description: getValueByHeaders(values, ['symptom', 'symptom_description', 'อาการ']),
                observation: getValueByHeaders(values, ['observation', 'ข้อสังเกต', 'สังเกต']),
                initial_check: getValueByHeaders(values, ['initial check', 'initial_check', 'ตรวจสอบเบื้องต้น']),
                possible_causes: getValueByHeaders(values, ['possible causes', 'possible_causes', 'สาเหตุ']),
                solution: getValueByHeaders(values, ['solution', 'วิธีแก้']),
                responsible_party: getValueByHeaders(values, ['responsible', 'responsible_party', 'ผู้รับผิดชอบ']),
                sheet_source: 'admin_upload',
                search_keywords: ''
            }

            record.embeddingContent = [
                `หมวดหมู่: ${record.category}`,
                `หมวดหมู่ย่อย: ${record.subcategory}`,
                `อาการ: ${record.symptom_description}`,
                `สาเหตุ: ${record.possible_causes}`,
                `วิธีแก้: ${record.solution}`
            ].join('\n')

            record.search_keywords = [
                record.category,
                record.subcategory,
                record.symptom_description
            ].filter(Boolean).join(' ')

            return record
        }).filter(r => r.category || r.symptom_description)

        console.log(`\n=== GENERATING EMBEDDINGS (${recordsToProcess.length} records) ===`)
        const recordsWithEmbeddings: any[] = []

        const BATCH_SIZE = 5;
        for (let i = 0; i < recordsToProcess.length; i += BATCH_SIZE) {
            const batch = recordsToProcess.slice(i, i + BATCH_SIZE);
            console.log(`Processing batch ${Math.floor(i / BATCH_SIZE) + 1}/${Math.ceil(recordsToProcess.length / BATCH_SIZE)}...`);

            await Promise.all(batch.map(async (record) => {
                let embedding = null;
                if (geminiService && record.embeddingContent) {
                    // Delay นิดหน่อยเพื่อป้องกัน Rate Limit (ถึงจะมีหลายคีย์ก็กันไว้ก่อน)
                    await new Promise(resolve => setTimeout(resolve, 100 * (i % 3)));
                    embedding = await geminiService.generateEmbedding(record.embeddingContent);
                }

                const { embeddingContent, ...dbRecord } = record;
                recordsWithEmbeddings.push({
                    ...dbRecord,
                    embedding: embedding
                });
            }));
        }

        console.log(`Generated embeddings for ${recordsWithEmbeddings.filter(r => r.embedding).length}/${recordsWithEmbeddings.length} records`)

        if (recordsWithEmbeddings.length === 0) {
            throw new Error('No valid records found.')
        }

        const { error: insertError } = await supabase
            .from('troubleshooting_guide')
            .insert(recordsWithEmbeddings)

        if (insertError) throw insertError

        await supabase.storage.from('admin-uploads').remove([fileName])

        return new Response(
            JSON.stringify({
                success: true,
                records: recordsWithEmbeddings.length,
                message: `Successfully processed ${recordsWithEmbeddings.length} records`
            }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )

    } catch (error: any) {
        console.error('ERROR:', error)
        return new Response(
            JSON.stringify({ success: false, error: error.message }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})