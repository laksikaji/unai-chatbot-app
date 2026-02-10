import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import * as XLSX from 'https://esm.sh/xlsx@0.18.5'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
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

        // 1. ดาวน์โหลดไฟล์จาก Storage
        const { data: fileData, error: downloadError } = await supabase.storage
            .from('admin-uploads')
            .download(fileName)

        if (downloadError) {
            console.error('Download error:', downloadError)
            throw downloadError
        }

        console.log('✓ File downloaded successfully')

        // 2. ตรวจสอบประเภทไฟล์
        const isExcel = fileName.toLowerCase().endsWith('.xlsx') || fileName.toLowerCase().endsWith('.xls')
        const isCSV = fileName.toLowerCase().endsWith('.csv')

        if (!isExcel && !isCSV) {
            throw new Error('Unsupported file type. Please upload CSV or Excel (.xlsx) files only.')
        }

        console.log('File type:', isExcel ? 'Excel' : 'CSV')

        let headers: string[] = []
        let dataRows: string[][] = []

        if (isExcel) {
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
            const parseCSVRow = (row: string): string[] => {
                const result: string[] = []
                let current = ''
                let inQuotes = false

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
                }
                result.push(current.trim().replace(/^["']|["']$/g, ''))
                return result
            }

            headers = parseCSVRow(lines[0])
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
            }
            return ''
        }

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

        return new Response(
            JSON.stringify({
                success: true,
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
