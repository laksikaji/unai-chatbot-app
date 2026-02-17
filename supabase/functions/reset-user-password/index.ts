import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const { email, newPassword } = await req.json()

        console.log('Received password reset request for:', email)

        if (!email || !newPassword) {
            return new Response(
                JSON.stringify({ error: 'Email and newPassword are required' }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        if (newPassword.length < 8) {
            return new Response(
                JSON.stringify({ error: 'Password must be at least 8 characters' }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        const supabaseUrl = Deno.env.get('SUPABASE_URL')!
        const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
        const supabase = createClient(supabaseUrl, supabaseKey, {
            auth: {
                autoRefreshToken: false,
                persistSession: false
            }
        })

        console.log('Looking up user...')

        // ค้นหา user จาก email
        const { data: userData, error: userError } = await supabase.auth.admin.listUsers()

        if (userError) {
            console.error('Error listing users:', userError)
            return new Response(
                JSON.stringify({ error: 'Failed to find user' }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        const user = userData?.users.find(u => u.email === email)

        if (!user) {
            console.log('User not found:', email)
            return new Response(
                JSON.stringify({ error: 'User not found' }),
                { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        console.log('User found, updating password...')

        // อัพเดทรหัสผ่าน
        const { error: updateError } = await supabase.auth.admin.updateUserById(
            user.id,
            { password: newPassword }
        )

        if (updateError) {
            console.error('Error updating password:', updateError)
            return new Response(
                JSON.stringify({ error: updateError.message }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        console.log('Password updated successfully')

        return new Response(
            JSON.stringify({ success: true, message: 'Password updated successfully' }),
            { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )

    } catch (error) {
        console.error('Error:', error)
        return new Response(
            JSON.stringify({ error: error.message }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})
