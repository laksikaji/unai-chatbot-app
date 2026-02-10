import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        console.log('Starting Google Sheets sync...')

        const GOOGLE_SHEET_ID = Deno.env.get('GOOGLE_SHEET_ID')
        const GOOGLE_API_KEY = Deno.env.get('GOOGLE_API_KEY')
        const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
        const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

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
        const cleanText = (text) => {
            if (!text) return ''
            return text.replace(/\n/g, ' / ').replace(/\s+/g, ' ').trim()
        }

        const records = dataRows
            .filter(row => row.length > 0 && row[0] && row[0].trim())
            .map(row => ({
                category: cleanText(row[0]),
                subcategory: cleanText(row[1]),
                symptom_description: cleanText(row[2]),
                observation: cleanText(row[3]),
                initial_check: cleanText(row[4]),
                possible_causes: cleanText(row[5]),
                solution: cleanText(row[6]),
                responsible_party: cleanText(row[7]),
                sheet_source: 'google_sheets',  // ✅ เปลี่ยนจาก 'troubleshooting_guide' เป็น 'google_sheets'
                search_keywords: [row[0], row[1], row[2], row[3], row[4]]
                    .filter(Boolean)
                    .map(t => cleanText(t))
                    .join(' ')
            }))

        console.log(`Processed ${records.length} records`)

        // ✅ ลบเฉพาะข้อมูลจาก Google Sheets (ไม่ลบข้อมูลที่อัปโหลดจากไฟล์)
        console.log('Deleting old Google Sheets data...')
        const deleteResponse = await fetch(
            `${SUPABASE_URL}/rest/v1/troubleshooting_guide?sheet_source=eq.google_sheets`,
            {
                method: 'DELETE',
                headers: {
                    'apikey': SUPABASE_SERVICE_KEY,
                    'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
                    'Content-Type': 'application/json',
                    'Prefer': 'return=minimal'
                }
            }
        )

        if (!deleteResponse.ok) {
            console.warn('Delete warning:', await deleteResponse.text())
        } else {
            console.log('✓ Old Google Sheets data deleted')
        }

        console.log('Inserting new data...')

        // Insert ข้อมูลใหม่ (ทีละ batch)
        let insertedCount = 0
        const batchSize = 100

        for (let i = 0; i < records.length; i += batchSize) {
            const batch = records.slice(i, i + batchSize)

            const insertResponse = await fetch(
                `${SUPABASE_URL}/rest/v1/troubleshooting_guide`,
                {
                    method: 'POST',
                    headers: {
                        'apikey': SUPABASE_SERVICE_KEY,
                        'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
                        'Content-Type': 'application/json',
                        'Prefer': 'return=representation'
                    },
                    body: JSON.stringify(batch)
                }
            )

            if (!insertResponse.ok) {
                const errorText = await insertResponse.text()
                console.error(`Batch ${i}-${i + batchSize} error:`, errorText)
                throw new Error(`Insert error: ${errorText}`)
            }

            const insertedData = await insertResponse.json()
            insertedCount += insertedData.length
            console.log(`Inserted batch ${i}-${i + batchSize}: ${insertedData.length} records`)
        }

        console.log(`✓ Sync complete! ${insertedCount} records from Google Sheets`)

        return new Response(
            JSON.stringify({
                success: true,
                message: `Synced ${insertedCount} records from Google Sheets (preserved uploaded files)`,
                records: insertedCount
            }),
            {
                status: 200,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
        )

    } catch (error) {
        console.error('Error:', error)
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
