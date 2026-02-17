<<<<<<< HEAD
// @ts-nocheck
=======
>>>>>>> 58ed6caa9461429e61c2b34b485ebbe7bac64624
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import * as XLSX from 'https://esm.sh/xlsx@0.18.5'

<<<<<<< HEAD
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

=======
>>>>>>> 58ed6caa9461429e61c2b34b485ebbe7bac64624
const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

<<<<<<< HEAD
serve(async (req: any) => {
=======
serve(async (req) => {
>>>>>>> 58ed6caa9461429e61c2b34b485ebbe7bac64624
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

<<<<<<< HEAD
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

=======
        // 1. ดาวน์โหลดไฟล์จาก Storage
>>>>>>> 58ed6caa9461429e61c2b34b485ebbe7bac64624
        const { data: fileData, error: downloadError } = await supabase.storage
            .from('admin-uploads')
            .download(fileName)

<<<<<<< HEAD
        if (downloadError) throw downloadError

        console.log('✓ File downloaded successfully')

=======
        if (downloadError) {
            console.error('Download error:', downloadError)
            throw downloadError
        }

        console.log('✓ File downloaded successfully')

        // 2. ตรวจสอบประเภทไฟล์
>>>>>>> 58ed6caa9461429e61c2b34b485ebbe7bac64624
        const isExcel = fileName.toLowerCase().endsWith('.xlsx') || fileName.toLowerCase().endsWith('.xls')
        const isCSV = fileName.toLowerCase().endsWith('.csv')

        if (!isExcel && !isCSV) {
            throw new Error('Unsupported file type. Please upload CSV or Excel (.xlsx) files only.')
        }

<<<<<<< HEAD
=======
        console.log('File type:', isExcel ? 'Excel' : 'CSV')

>>>>>>> 58ed6caa9461429e61c2b34b485ebbe7bac64624
        let headers: string[] = []
        let dataRows: string[][] = []

        if (isExcel) {
<<<<<<< HEAD
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

=======
            // Parse Excel file
            console.log('Parsing Excel file...')
            const arrayBuffer = await fileData.arrayBuffer()
            const workbook = XLSX.read(arrayBuffer, { type: 'array' })

            // ใช้ sheet แรก
            const sheetName = workbook.SheetNames[0]
            const worksheet = workbook.Sheets[sheetName]
            console.log('Sheet name:', sheetName)

            // แปลงเป็น array of arrays
            const data = XLSX.utils.sheet_to_json(worksheet, { header: 1, defval: '' }) as string[][]

            if (data.length < 2) {
                throw new Error('Excel file is empty or has no data rows')
            }

            headers = data[0].map(h => String(h).trim())
            dataRows = data.slice(1).filter(row => row.some(cell => cell && String(cell).trim()))

        } else {
            // Parse CSV file
            console.log('Parsing CSV file...')
            const text = await fileData.text()
            console.log('File size:', text.length, 'characters')

            const lines = text.split('\n').filter(line => line.trim())
            console.log('Total lines (including header):', lines.length)

            if (lines.length < 2) {
                throw new Error('CSV file is empty or has no data rows')
            }

            // Parse CSV row with proper quote handling
>>>>>>> 58ed6caa9461429e61c2b34b485ebbe7bac64624
            const parseCSVRow = (row: string): string[] => {
                const result: string[] = []
                let current = ''
                let inQuotes = false
<<<<<<< HEAD
                for (let i = 0; i < row.length; i++) {
                    const char = row[i]
                    if (char === '"') inQuotes = !inQuotes
                    else if (char === ',' && !inQuotes) {
                        result.push(current.trim().replace(/^["']|["']$/g, ''))
                        current = ''
                    } else current += char
=======

                for (let i = 0; i < row.length; i++) {
                    const char = row[i]
                    if (char === '"') {
                        inQuotes = !inQuotes
                    } else if (char === ',' && !inQuotes) {
                        result.push(current.trim().replace(/^["']|["']$/g, ''))
                        current = ''
                    } else {
                        current += char
                    }
>>>>>>> 58ed6caa9461429e61c2b34b485ebbe7bac64624
                }
                result.push(current.trim().replace(/^["']|["']$/g, ''))
                return result
            }

            headers = parseCSVRow(lines[0])
<<<<<<< HEAD
            dataRows = lines.slice(1).map((line: string) => parseCSVRow(line))
        }

        const normalizeHeader = (header: string) => String(header).toLowerCase().trim().replace(/\s+/g, ' ')
        const headerMap: { [key: string]: number } = {}
        headers.forEach((h, i) => headerMap[normalizeHeader(h)] = i)

        const getValueByHeaders = (values: string[], possibleHeaders: string[]) => {
            for (const h of possibleHeaders) {
                const idx = headerMap[normalizeHeader(h)]
                if (idx !== undefined && values[idx]) return String(values[idx]).trim()
=======
            dataRows = lines.slice(1).map(line => parseCSVRow(line))
        }

        console.log('=== HEADERS DETECTED ===')
        console.log('Number of columns:', headers.length)
        headers.forEach((h, i) => {
            console.log(`Column ${i + 1}: "${h}"`)
        })

        console.log('\n=== DATA ROWS ===')
        console.log('Number of data rows:', dataRows.length)

        // Clean text helper
        const cleanText = (text: string) => {
            if (!text) return ''
            return String(text)
                .replace(/^["']|["']$/g, '')
                .replace(/\n/g, ' / ')
                .replace(/\s+/g, ' ')
                .trim()
        }

        // Normalize header for matching
        const normalizeHeader = (header: string): string => {
            return String(header).toLowerCase().trim().replace(/\s+/g, ' ')
        }

        // Create header mapping
        const headerMap: { [key: string]: number } = {}
        headers.forEach((header, index) => {
            const normalized = normalizeHeader(header)
            headerMap[normalized] = index
        })

        console.log('\n=== HEADER MAPPING ===')
        console.log(JSON.stringify(headerMap, null, 2))

        // Helper to get value by multiple possible header names
        const getValueByHeaders = (values: string[], possibleHeaders: string[]): string => {
            for (const header of possibleHeaders) {
                const normalized = normalizeHeader(header)
                if (headerMap[normalized] !== undefined) {
                    const value = values[headerMap[normalized]]
                    if (value) {
                        return cleanText(value)
                    }
                }
>>>>>>> 58ed6caa9461429e61c2b34b485ebbe7bac64624
            }
            return ''
        }

<<<<<<< HEAD
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
=======
        // Process each row
        const records = dataRows
            .filter(row => row.some(cell => cell && String(cell).trim()))
            .map((values, rowIndex) => {
                console.log(`\n--- Row ${rowIndex + 1} ---`)
                console.log('Number of values:', values.length)
                values.forEach((v, i) => {
                    console.log(`  [${i + 1}] ${headers[i] || 'unknown'}: "${v}"`)
                })

                const record = {
                    category: getValueByHeaders(values, ['category', 'หมวดหมู่', 'ประเภทหลัก']),
                    subcategory: getValueByHeaders(values, ['subcategory', 'หมวดหมู่ย่อย', 'หมวดหมู่ ย่อย', 'ประเภท']),
                    symptom_description: getValueByHeaders(values, ['symptom', 'symptom_description', 'อาการ']),
                    observation: getValueByHeaders(values, ['observation', 'ข้อสังเกต', 'สังเกต', 'ข้อสังเกตุ']),
                    initial_check: getValueByHeaders(values, [
                        'initial check',
                        'initial_check',
                        'ตรวจสอบเบื้องต้น',
                        'เช็คเบื้องต้น',
                        'ตรวจสอบ เบื้องต้น'
                    ]),
                    possible_causes: getValueByHeaders(values, [
                        'possible causes',
                        'possible_causes',
                        'สาเหตุที่เป็นไปได้',
                        'สาเหตุที่อาจเป็นไปได้',
                        'สาเหตุ',
                        'สาเหตุ ที่เป็นไปได้'
                    ]),
                    solution: getValueByHeaders(values, ['solution', 'วิธีแก้', 'วิธี แก้']),
                    responsible_party: getValueByHeaders(values, [
                        'responsible',
                        'responsible_party',
                        'ผู้รับผิดชอบ',
                        'ผู้ รับผิดชอบ',
                        'ผู้แก้ปัญหาเบื้องต้น'
                    ]),
                    sheet_source: 'admin_upload',
                    search_keywords: ''
                }

                // Build search keywords from non-empty fields
                record.search_keywords = [
                    record.category,
                    record.subcategory,
                    record.symptom_description
                ].filter(Boolean).join(' ')

                console.log('\n=== MAPPED RECORD ===')
                console.log(JSON.stringify(record, null, 2))

                return record
            })
            .filter(record => record.category || record.symptom_description)

        console.log('\n=== PROCESSING SUMMARY ===')
        console.log(`Valid records to insert: ${records.length}`)

        if (records.length === 0) {
            throw new Error('No valid records found in file. At least category or symptom is required.')
        }

        // 5. Insert ลง database
        console.log('\n=== INSERTING TO DATABASE ===')
        const { error: insertError } = await supabase
            .from('troubleshooting_guide')
            .insert(records)

        if (insertError) {
            console.error('Insert error:', insertError)
            throw insertError
        }

        console.log('✓ Data inserted successfully')

        // 6. ลบไฟล์ออกจาก Storage
        await supabase.storage.from('admin-uploads').remove([fileName])
        console.log('✓ File cleaned up')
>>>>>>> 58ed6caa9461429e61c2b34b485ebbe7bac64624

        return new Response(
            JSON.stringify({
                success: true,
<<<<<<< HEAD
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
=======
                records: records.length,
                message: `Successfully processed ${records.length} records from ${isExcel ? 'Excel' : 'CSV'} file`
            }),
            {
                status: 200,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
        )

    } catch (error) {
        console.error('❌ ERROR:', error)
        return new Response(
            JSON.stringify({
                success: false,
                error: error.message
            }),
            {
                status: 500,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
        )
    }
})
>>>>>>> 58ed6caa9461429e61c2b34b485ebbe7bac64624
