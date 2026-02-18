// @ts-nocheck
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Embedding Service - ใช้ GEMINI_EMBEDDING_KEY + v1beta
class GeminiEmbeddingService {
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
                console.error(`Gemini Embedding API Error (Key ends with ...${this.apiKey.slice(-4)}):`, await response.text());
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

// Chat Service - ใช้ GEMINI_API_KEY_1 ถึง _5 + v1beta + gemini-2.5-flash
class GeminiChatService {
    private apiKeys: string[];
    private baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

    // Gemini free tier limit (requests per day per key)
    static readonly DAILY_LIMIT = 1500;

    constructor(apiKeys: string[]) {
        this.apiKeys = apiKeys;
    }

    // สุ่ม key และ return ทั้ง key + index (1-based)
    private getRandomKeyWithIndex(): { key: string; index: number } {
        const index = Math.floor(Math.random() * this.apiKeys.length);
        return { key: this.apiKeys[index], index: index + 1 };
    }

    async chat(prompt: string, context: string): Promise<{
        text: string;
        keyIndex: number;
        success: boolean;
    }> {
        const { key: apiKey, index: keyIndex } = this.getRandomKeyWithIndex();
        console.log(`Using Gemini key #${keyIndex} ending in ...${apiKey.slice(-4)}`);

        const systemPrompt = `
คุณคือ "UNAi" ผู้ช่วย AI อัจฉริยะ
**บทบาทและหน้าที่ของคุณ:**
*   ตอบคำถามโดยอ้างอิงจากข้อมูลใน "CONTEXT" ที่ให้มาเท่านั้น
*   ช่วยเหลือในการแก้ไขปัญหา (Troubleshooting) ตามคู่มือที่มี
*   ให้บริการด้วยความสุภาพ และเป็นมืออาชีพ
**คำแนะนำในการตอบ:**
*   ใช้ข้อมูลจาก "CONTEXT" ด้านล่างนี้ในการตอบคำถามเป็นหลัก
*   ถ้าข้อมูลใน CONTEXT เพียงพอ ให้ตอบสรุปใจความสำคัญให้เข้าใจง่าย
*   ถ้าข้อมูลใน CONTEXT ไม่เพียงพอ หรือไม่เกี่ยวข้องกับคำถาม ให้ตอบว่า "ขออภัยครับ ผมไม่มีข้อมูลเกี่ยวกับเรื่องนี้ในฐานข้อมูล" (ห้ามแต่งเรื่องเอง)
*   ใช้ภาษาไทยที่สุภาพ

CONTEXT:
${context}
    `.trim();

        try {
            const response = await fetch(
                `${this.baseUrl}/gemini-2.5-flash:generateContent?key=${apiKey}`,
                {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        contents: [{
                            role: 'user',
                            parts: [{ text: systemPrompt + '\n\nคำถาม: ' + prompt }]
                        }]
                    }),
                }
            );
            if (!response.ok) {
                const errorText = await response.text();
                console.error(`Gemini Chat API Error: ${errorText}`);
                return {
                    text: `ขออภัยครับ ระบบ AI ขัดข้องชั่วคราว (${response.status})`,
                    keyIndex,
                    success: false,
                };
            }
            const data = await response.json();
            return {
                text: data.candidates[0].content.parts[0].text,
                keyIndex,
                success: true,
            };
        } catch (error) {
            console.error('Error generating chat response:', error);
            return {
                text: 'ขออภัยครับ เกิดข้อผิดพลาดในการเชื่อมต่อกับ AI',
                keyIndex,
                success: false,
            };
        }
    }
}

// Groq Service - ใช้ GROQ_API_KEY_1 ถึง _5 (สุ่ม key) + บันทึก usage
class GroqService {
    private apiKeys: string[];

    constructor(apiKeys: string[]) {
        this.apiKeys = apiKeys;
    }

    // สุ่ม key และ return ทั้ง key + index (1-based)
    private getRandomKeyWithIndex(): { key: string; index: number } {
        const index = Math.floor(Math.random() * this.apiKeys.length);
        return { key: this.apiKeys[index], index: index + 1 }; // index 1-based
    }

    async chat(message: string, contextText: string): Promise<{
        text: string;
        keyIndex: number;
        requestsRemaining: number | null;
        requestsLimit: number | null;
        tokensRemaining: number | null;
        tokensLimit: number | null;
        resetTime: string | null;
    }> {
        const { key: apiKey, index: keyIndex } = this.getRandomKeyWithIndex();
        console.log(`Using Groq key #${keyIndex} ending in ...${apiKey.slice(-4)}`);

        const systemContent = `
คุณคือ "UNAi" ผู้ช่วย AI อัจฉริยะ
**บทบาทและหน้าที่ของคุณ:**
*   ตอบคำถามโดยอ้างอิงจากข้อมูลใน "CONTEXT" ที่ให้มาเท่านั้น
*   ช่วยเหลือในการแก้ไขปัญหา (Troubleshooting) ตามคู่มือที่มี
*   ให้บริการด้วยความสุภาพ และเป็นมืออาชีพ
**คำแนะนำในการตอบ:**
*   ใช้ข้อมูลจาก "CONTEXT" ด้านล่างนี้ในการตอบคำถามเป็นหลัก
*   ถ้าข้อมูลใน CONTEXT เพียงพอ ให้ตอบสรุปใจความสำคัญให้เข้าใจง่าย
*   ถ้าข้อมูลใน CONTEXT ไม่เพียงพอ หรือไม่เกี่ยวข้องกับคำถาม ให้ตอบว่า "ขออภัยครับ ผมไม่มีข้อมูลเกี่ยวกับเรื่องนี้ในฐานข้อมูล" (ห้ามแต่งเรื่องเอง)
*   ใช้ภาษาไทยที่สุภาพ

CONTEXT:
${contextText || 'ไม่พบข้อมูลในฐานข้อมูล ตอบตามความรู้ทั่วไป'}
    `.trim();

        const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${apiKey}`,
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                messages: [
                    { role: 'system', content: systemContent },
                    { role: 'user', content: message },
                ],
                model: 'llama-3.3-70b-versatile',
                stream: false,
            }),
        });

        // ดึง rate limit headers จาก Groq response
        const requestsRemaining = parseInt(response.headers.get('x-ratelimit-remaining-requests') ?? '') || null;
        const requestsLimit = parseInt(response.headers.get('x-ratelimit-limit-requests') ?? '') || null;
        const tokensRemaining = parseInt(response.headers.get('x-ratelimit-remaining-tokens') ?? '') || null;
        const tokensLimit = parseInt(response.headers.get('x-ratelimit-limit-tokens') ?? '') || null;
        const resetTime = response.headers.get('x-ratelimit-reset-requests') ?? null;

        if (!response.ok) {
            const errorText = await response.text();
            console.error(`Groq API Error (${response.status}):`, errorText);
            throw new Error(`Groq API Error (${response.status}): ${errorText}`);
        }

        const data = await response.json();
        if (!data.choices?.[0]?.message?.content) {
            console.error('Invalid Groq response format:', JSON.stringify(data));
            throw new Error('Invalid Groq response format');
        }

        return {
            text: data.choices[0].message.content,
            keyIndex,
            requestsRemaining,
            requestsLimit,
            tokensRemaining,
            tokensLimit,
            resetTime,
        };
    }
}

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const { message } = await req.json()

        const supabaseUrl = Deno.env.get('SUPABASE_URL')!
        const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
        const supabase = createClient(supabaseUrl, supabaseKey)

        // Load GEMINI_EMBEDDING_KEY สำหรับ embedding
        const embeddingKey = Deno.env.get('GEMINI_EMBEDDING_KEY');
        const embeddingService = embeddingKey ? new GeminiEmbeddingService(embeddingKey) : null;
        if (!embeddingKey) console.warn('WARNING: GEMINI_EMBEDDING_KEY not found');

        // Load GEMINI_API_KEY_1 ถึง _5 สำหรับ chat
        const chatKeys: string[] = [];
        for (let i = 1; i <= 5; i++) {
            const key = Deno.env.get(`GEMINI_API_KEY_${i}`);
            if (key) chatKeys.push(key);
        }
        const chatService = chatKeys.length > 0 ? new GeminiChatService(chatKeys) : null;
        console.log(`Loaded ${chatKeys.length} Gemini chat key(s)`);

        // Load GROQ_API_KEY_1 ถึง _5 สำหรับ Groq
        const groqKeys: string[] = [];
        for (let i = 1; i <= 5; i++) {
            const key = Deno.env.get(`GROQ_API_KEY_${i}`);
            if (key) groqKeys.push(key);
        }
        // Fallback: ลองอ่าน GROQ_API_KEY ตัวเดียวด้วย
        const singleGroqKey = Deno.env.get('GROQ_API_KEY');
        if (singleGroqKey && groqKeys.length === 0) groqKeys.push(singleGroqKey);
        const groqService = groqKeys.length > 0 ? new GroqService(groqKeys) : null;
        console.log(`Loaded ${groqKeys.length} Groq key(s)`);

        // Load AI Provider setting
        const { data: setting } = await supabase
            .from('system_settings')
            .select('value')
            .eq('key', 'ai_provider')
            .single()

        const aiProvider = setting?.value || 'groq'
        console.log(`Using AI Provider: ${aiProvider}`)

        // Generate Embedding สำหรับ vector search
        let contextText = ''
        if (embeddingService) {
            const embedding = await embeddingService.generateEmbedding(message)

            if (embedding) {
                const { data: documents, error: matchError } = await supabase.rpc(
                    'match_troubleshooting_guide',
                    {
                        query_embedding: embedding,
                        match_threshold: 0.5,
                        match_count: 5
                    }
                )
                if (!matchError && documents && documents.length > 0) {
                    contextText = documents.map((doc: any) =>
                        `หัวข้อ: ${doc.category} - ${doc.subcategory}\n` +
                        `อาการ: ${doc.symptom_description}\n` +
                        `สาเหตุ: ${doc.possible_causes}\n` +
                        `วิธีแก้: ${doc.solution}`
                    ).join('\n---\n')
                    console.log(`Found ${documents.length} relevant documents.`)
                } else {
                    if (matchError) console.error('Match error:', matchError)
                    else console.log('No relevant documents found.')
                }
            }
        }

        // Fallback text search ถ้าไม่เจอ context จาก vector
        if (!contextText) {
            const { data: textDocs } = await supabase
                .from('troubleshooting_guide')
                .select('*')
                .textSearch('search_keywords', `'${message}'`, { type: 'websearch', config: 'english' })
                .limit(3);

            if (textDocs && textDocs.length > 0) {
                contextText = textDocs.map((doc: any) =>
                    `หัวข้อ: ${doc.category}\nอาการ: ${doc.symptom_description}\nวิธีแก้: ${doc.solution}`
                ).join('\n---\n')
                console.log(`Found ${textDocs.length} documents via text search.`)
            }
        }

        let responseText = ''

        if (aiProvider === 'gemini' && chatService) {
            const result = await chatService.chat(message, contextText);
            responseText = result.text;

            // บันทึก Gemini usage ด้วย upsert (นับถอยหลังต่อวัน)
            // ดึง log ล่าสุดของ key นี้มาก่อน เพื่อคำนวณ requests_remaining
            supabase.from('api_usage_logs')
                .select('requests_remaining, timestamp')
                .eq('api_key_index', result.keyIndex + 10) // offset +10 เพื่อแยก Gemini (11-15) ออกจาก Groq (1-5)
                .order('timestamp', { ascending: false })
                .limit(1)
                .then(async ({ data: prevLog }) => {
                    const now = new Date();
                    const limit = GeminiChatService.DAILY_LIMIT;

                    // เช็คว่า log เดิมเป็นวันเดียวกันไหม ถ้าไม่ใช่ให้ reset
                    let prevRemaining = limit;
                    if (prevLog && prevLog.length > 0) {
                        const prevDate = new Date(prevLog[0].timestamp);
                        const isSameDay = prevDate.toDateString() === now.toDateString();
                        prevRemaining = isSameDay ? (prevLog[0].requests_remaining ?? limit) : limit;
                    }

                    const newRemaining = Math.max(0, prevRemaining - (result.success ? 1 : 0));
                    // reset_time: เวลา midnight ของวันถัดไป (Pacific Time offset ~-8h)
                    const resetDate = new Date(now);
                    resetDate.setUTCHours(8, 0, 0, 0); // midnight PT = 08:00 UTC
                    if (now.getUTCHours() >= 8) resetDate.setUTCDate(resetDate.getUTCDate() + 1);
                    const msUntilReset = resetDate.getTime() - now.getTime();
                    const hUntilReset = Math.floor(msUntilReset / 3600000);
                    const mUntilReset = Math.floor((msUntilReset % 3600000) / 60000);
                    const resetTimeStr = `${hUntilReset}h${mUntilReset}m`;

                    const { error } = await supabase.from('api_usage_logs').insert({
                        api_key_index: result.keyIndex + 10, // Gemini key index: 11-15
                        requests_remaining: newRemaining,
                        requests_limit: limit,
                        tokens_remaining: null,
                        tokens_limit: null,
                        reset_time: resetTimeStr,
                        timestamp: now.toISOString(),
                    });

                    if (error) console.error('Failed to log Gemini usage:', error.message);
                    else console.log(`Logged Gemini key #${result.keyIndex} usage: ${newRemaining}/${limit} remaining`);
                });

        } else if (groqService) {
            const result = await groqService.chat(message, contextText);
            responseText = result.text;

            // บันทึก Groq API usage ลง Supabase (ไม่ block response)
            supabase.from('api_usage_logs').insert({
                api_key_index: result.keyIndex,
                requests_remaining: result.requestsRemaining,
                requests_limit: result.requestsLimit,
                tokens_remaining: result.tokensRemaining,
                tokens_limit: result.tokensLimit,
                reset_time: result.resetTime,
                timestamp: new Date().toISOString(),
            }).then(({ error }) => {
                if (error) console.error('Failed to log API usage:', error.message);
                else console.log(`Logged usage for Groq key #${result.keyIndex}: ${result.requestsRemaining}/${result.requestsLimit} remaining`);
            });
        } else {
            responseText = 'ขออภัยครับ ไม่พบ API Key สำหรับ AI ในระบบ กรุณาตรวจสอบ Secrets ใน Supabase';
        }

        return new Response(
            JSON.stringify({ response: responseText }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    } catch (error: any) {
        console.error('Error:', error)
        return new Response(
            JSON.stringify({ error: error.message }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})