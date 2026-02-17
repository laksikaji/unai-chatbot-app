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
        console.log('Starting clear troubleshooting data...')

        const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
        const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

        if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
            throw new Error('Missing Supabase credentials')
        }

        console.log('Deleting all data from troubleshooting_guide...')

        // ลบข้อมูลทั้งหมดจากตาราง troubleshooting_guide
        const deleteResponse = await fetch(
            `${SUPABASE_URL}/rest/v1/troubleshooting_guide?id=neq.00000000-0000-0000-0000-000000000000`,
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
            const errorText = await deleteResponse.text()
            throw new Error(`Delete error: ${errorText}`)
        }

        console.log('All data cleared successfully!')

        return new Response(
            JSON.stringify({
                success: true,
                message: 'All troubleshooting data cleared successfully'
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
