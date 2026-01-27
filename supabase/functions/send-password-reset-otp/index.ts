import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { SMTPClient } from 'https://deno.land/x/denomailer@1.6.0/mod.ts'

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
    const { email } = await req.json()

    console.log('📧 Received request for email:', email)

    if (!email) {
      return new Response(
        JSON.stringify({ error: 'Email is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    console.log('🔍 Checking if user exists...')

    const { data: userData, error: userError } = await supabase.auth.admin.listUsers()

    if (userError) {
      console.error('❌ Error listing users:', userError)
      return new Response(
        JSON.stringify({ error: 'Failed to check user' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const userExists = userData?.users.some(u => u.email === email)

    if (!userExists) {
      console.log('❌ User not found:', email)
      return new Response(
        JSON.stringify({ error: 'Email not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log('✅ User exists, generating OTP...')

    // ลบ OTP เก่าของ email นี้ทิ้งเลย
    const { error: deleteError } = await supabase
      .from('password_reset_otps')
      .delete()
      .eq('email', email)

    if (deleteError) {
      console.error('⚠️ Error deleting old OTPs:', deleteError)
    } else {
      console.log('✅ Deleted old OTPs')
    }

    const otp = Math.floor(100000 + Math.random() * 900000).toString()

    console.log('🔢 OTP generated:', otp)

    // บันทึก OTP ลงฐานข้อมูล
    const { data: insertData, error: insertError } = await supabase
      .from('password_reset_otps')
      .insert({
        email,
        otp_code: otp,
      })
      .select()

    if (insertError) {
      console.error('❌ Insert error:', insertError)
      return new Response(
        JSON.stringify({ error: 'Failed to create OTP', details: insertError.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log('✅ OTP saved to database:', insertData)

    // ส่งอีเมลผ่าน Gmail SMTP
    const GMAIL_USER = Deno.env.get('GMAIL_USER')
    const GMAIL_APP_PASSWORD = Deno.env.get('GMAIL_APP_PASSWORD')
    const GMAIL_FROM_NAME = Deno.env.get('GMAIL_FROM_NAME') || 'UNAI Chatbot'

    if (!GMAIL_USER || !GMAIL_APP_PASSWORD) {
      console.error('❌ Gmail credentials not found')
      return new Response(
        JSON.stringify({ error: 'Email service not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log('📨 Sending email via Gmail SMTP...')

    const client = new SMTPClient({
      connection: {
        hostname: 'smtp.gmail.com',
        port: 465,
        tls: true,
        auth: {
          username: GMAIL_USER,
          password: GMAIL_APP_PASSWORD,
        },
      },
    })

    // HTML with English text to avoid encoding issues
    const htmlContent = `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="font-family: Arial, sans-serif; background-color: #f4f4f4; margin: 0; padding: 20px;">
  <table width="100%" cellpadding="0" cellspacing="0" style="max-width: 600px; margin: 0 auto;">
    <tr>
      <td>
        <table width="100%" cellpadding="0" cellspacing="0" style="background: white; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.1);">
          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #2563eb, #1e40af); background-color: #2563eb; padding: 30px; text-align: center;">
              <h1 style="color: white; margin: 0; font-size: 28px; font-weight: bold;">UNAI Chatbot</h1>
            </td>
          </tr>
          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <h2 style="color: #1f2937; margin-top: 0; font-size: 24px;">Password Reset OTP</h2>
              <p style="color: #4b5563; font-size: 16px; line-height: 1.6; margin: 20px 0;">
                You have requested to reset your password for UNAI Chatbot account.<br>
                Please use the OTP code below to verify your identity:
              </p>
              <!-- OTP Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="margin: 30px 0;">
                <tr>
                  <td style="background: #f3f4f6; padding: 30px; text-align: center; border-radius: 12px;">
                    <p style="color: #1e3a8a; font-size: 42px; font-weight: bold; letter-spacing: 12px; margin: 0;">${otp}</p>
                  </td>
                </tr>
              </table>
              <p style="color: #ef4444; font-weight: 600; text-align: center; font-size: 16px; margin: 20px 0;">
                This OTP will expire in 10 minutes
              </p>
              <p style="color: #6b7280; font-size: 14px; margin-top: 30px;">
                If you did not request a password reset, please ignore this email.
              </p>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="background: #f9fafb; padding: 20px; text-align: center;">
              <p style="color: #6b7280; font-size: 14px; margin: 0;">UNAI Chatbot</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`

    // ส่งเฉพาะ HTML
    await client.send({
      from: `${GMAIL_FROM_NAME} <${GMAIL_USER}>`,
      to: email,
      subject: 'Password Reset OTP - UNAI Chatbot',
      html: htmlContent,
    })

    await client.close()

    console.log('✅ Email sent successfully via Gmail')

    return new Response(
      JSON.stringify({ success: true, message: 'OTP sent successfully' }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('❌ Error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
