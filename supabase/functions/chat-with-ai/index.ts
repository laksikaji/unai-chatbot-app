// @ts-nocheck
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

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

class GeminiChatService {
    private apiKeys: string[];
    private baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

    constructor(apiKeys: string[]) {
        this.apiKeys = apiKeys;
    }

    private getRandomKey(): string {
        return this.apiKeys[Math.floor(Math.random() * this.apiKeys.length)];
    }

    async chat(prompt: string, context: string): Promise<string> {
        const apiKey = this.getRandomKey();

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
                `${this.baseUrl}/gemini-1.5-flash:generateContent?key=${apiKey}`,
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
                return `ขออภัยครับ ระบบ AI ขัดข้องชั่วคราว (${response.status})`;
            }

            const data = await response.json();
            return data.candidates[0].content.parts[0].text;
        } catch (error) {
            console.error('Error generating chat response:', error);
            return 'ขออภัยครับ เกิดข้อผิดพลาดในการเชื่อมต่อกับ AI';
        }
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

        const groqApiKey = Deno.env.get('GROQ_API_KEY')

        // ✅ แยก Key สำหรับ Embedding
        const embeddingKey = Deno.env.get('GEMINI_EMBEDDING_KEY');
        const embeddingService = embeddingKey ? new GeminiEmbeddingService(embeddingKey) : null;

        // ✅ แยก Keys 1-5 สำหรับ Chat
        const chatKeys: string[] = [];
        for (let i = 1; i <= 5; i++) {
            const key = Deno.env.get(`GEMINI_API_KEY_${i}`);
            if (key) chatKeys.push(key);
        }
        const singleChatKey = Deno.env.get('GEMINI_API_KEY');
        if (singleChatKey && chatKeys.length === 0) chatKeys.push(singleChatKey);

        const chatService = chatKeys.length > 0 ? new GeminiChatService(chatKeys) : null;

        const { data: setting } = await supabase
            .from('system_settings')
            .select('value')
            .eq('key', 'ai_provider')
            .single()

        const aiProvider = setting?.value || 'groq'
        console.log(`Using AI Provider: ${aiProvider}`)

        let contextText = ''

        // ✅ ใช้ embeddingService สำหรับ generate query vector
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

                if (!matchError && documents) {
                    contextText = documents.map((doc: any) =>
                        `หัวข้อ: ${doc.category} - ${doc.subcategory}\n` +
                        `อาการ: ${doc.symptom_description}\n` +
                        `สาเหตุ: ${doc.possible_causes}\n` +
                        `วิธีแก้: ${doc.solution}`
                    ).join('\n---\n')

                    console.log(`Found ${documents.length} relevant documents.`)
                } else {
                    console.error('Match error:', matchError)
                }
            }
        }

        let responseText = ''

        // ✅ ใช้ chatService สำหรับตอบคำถาม
        if (aiProvider === 'gemini' && chatService) {
            responseText = await chatService.chat(message, contextText);

        } else {
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
                }
            }

            const systemContent = `
คุณคือ "UNAi" ผู้ช่วย AI อัจฉริยะ

CONTEXT:
${contextText || 'ไม่พบข้อมูลในฐานข้อมูล ตอบตามความรู้ทั่วไป'}
        `.trim();

            const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${groqApiKey}`,
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    messages: [
                        { role: 'system', content: systemContent },
                        { role: 'user', content: message },
                    ],
                    model: 'llama3-70b-8192',
                    stream: false,
                }),
            })

            const data = await response.json()
            responseText = data.choices[0]?.message?.content || 'ขออภัยครับ ไม่สามารถเชื่อมต่อกับ Groq ได้'
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