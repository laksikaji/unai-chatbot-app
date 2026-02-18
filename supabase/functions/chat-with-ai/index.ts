// @ts-nocheck
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// ─── Constants ────────────────────────────────────────────────
const GEMINI_CHAT_LIMIT = 1500;   // requests/day per key (free tier)
const GEMINI_EMBED_LIMIT = 1500;  // requests/day (1 key)
const EMBED_KEY_INDEX = 21;       // Embedding key index in api_usage_logs

// ─── Helper: บันทึก Gemini usage (นับถอยหลัง reset รายวัน) ──
async function logGeminiUsage(
    supabase: any,
    keyIndex: number,
    limit: number,
    success: boolean
) {
    try {
        const { data: prevLog } = await supabase
            .from('api_usage_logs')
            .select('requests_remaining, timestamp')
            .eq('api_key_index', keyIndex)
            .order('timestamp', { ascending: false })
            .limit(1);

        const now = new Date();
        let prevRemaining = limit;
        if (prevLog && prevLog.length > 0) {
            const prevDate = new Date(prevLog[0].timestamp);
            const isSameDay = prevDate.toDateString() === now.toDateString();
            prevRemaining = isSameDay ? (prevLog[0].requests_remaining ?? limit) : limit;
        }

        const newRemaining = Math.max(0, prevRemaining - (success ? 1 : 0));

        const resetDate = new Date(now);
        resetDate.setUTCHours(8, 0, 0, 0);
        if (now.getUTCHours() >= 8) resetDate.setUTCDate(resetDate.getUTCDate() + 1);
        const ms = resetDate.getTime() - now.getTime();
        const resetTimeStr = `${Math.floor(ms / 3600000)}h${Math.floor((ms % 3600000) / 60000)}m`;

        const { error } = await supabase.from('api_usage_logs').insert({
            api_key_index: keyIndex,
            requests_remaining: newRemaining,
            requests_limit: limit,
            tokens_remaining: null,
            tokens_limit: null,
            reset_time: resetTimeStr,
            timestamp: now.toISOString(),
        });

        if (error) console.error(`Failed to log usage (index ${keyIndex}):`, error.message);
        else console.log(`Logged usage index #${keyIndex}: ${newRemaining}/${limit} remaining`);
    } catch (e) {
        console.error('logGeminiUsage error:', e);
    }
}

// ─── Embedding Service ────────────────────────────────────────
class GeminiEmbeddingService {
    private apiKey: string;
    private baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

    constructor(apiKey: string) {
        this.apiKey = apiKey;
    }

    async generateEmbedding(text: string): Promise<{ values: number[] | null; success: boolean }> {
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
                console.error(`Gemini Embedding Error (Key ...${this.apiKey.slice(-4)}):`, await response.text());
                return { values: null, success: false };
            }
            const data = await response.json();
            return { values: data.embedding?.values ?? null, success: true };
        } catch (error) {
            console.error('Error generating embedding:', error);
            return { values: null, success: false };
        }
    }
}

// ─── Gemini Chat Service ──────────────────────────────────────
class GeminiChatService {
    private apiKeys: string[];
    private baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

    constructor(apiKeys: string[]) {
        this.apiKeys = apiKeys;
    }

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
        console.log(`Using Gemini chat key #${keyIndex} ending in ...${apiKey.slice(-4)}`);

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
                        contents: [{ role: 'user', parts: [{ text: systemPrompt + '\n\nคำถาม: ' + prompt }] }]
                    }),
                }
            );
            if (!response.ok) {
                const errorText = await response.text();
                console.error(`Gemini Chat API Error: ${errorText}`);
                return { text: `ขออภัยครับ ระบบ AI ขัดข้องชั่วคราว (${response.status})`, keyIndex, success: false };
            }
            const data = await response.json();
            return { text: data.candidates[0].content.parts[0].text, keyIndex, success: true };
        } catch (error) {
            console.error('Error generating chat response:', error);
            return { text: 'ขออภัยครับ เกิดข้อผิดพลาดในการเชื่อมต่อกับ AI', keyIndex, success: false };
        }
    }
}

// ─── Groq Service ────────────────────────────────────────────
class GroqService {
    private apiKeys: string[];

    constructor(apiKeys: string[]) {
        this.apiKeys = apiKeys;
    }

    private getRandomKeyWithIndex(): { key: string; index: number } {
        const index = Math.floor(Math.random() * this.apiKeys.length);
        return { key: this.apiKeys[index], index: index + 1 };
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
            headers: { 'Authorization': `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
            body: JSON.stringify({
                messages: [{ role: 'system', content: systemContent }, { role: 'user', content: message }],
                model: 'llama-3.3-70b-versatile',
                stream: false,
            }),
        });

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
        if (!data.choices?.[0]?.message?.content) throw new Error('Invalid Groq response format');

        return { text: data.choices[0].message.content, keyIndex, requestsRemaining, requestsLimit, tokensRemaining, tokensLimit, resetTime };
    }
}

// ─── CORS ─────────────────────────────────────────────────────
const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// ─── Main Handler ─────────────────────────────────────────────
serve(async (req) => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

    try {
        const { message } = await req.json();
        const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
        const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
        const supabase = createClient(supabaseUrl, supabaseKey);

        const embeddingKey = Deno.env.get('GEMINI_EMBEDDING_KEY');
        const embeddingService = embeddingKey ? new GeminiEmbeddingService(embeddingKey) : null;
        if (!embeddingKey) console.warn('WARNING: GEMINI_EMBEDDING_KEY not found');

        const chatKeys: string[] = [];
        for (let i = 1; i <= 5; i++) {
            const key = Deno.env.get(`GEMINI_API_KEY_${i}`);
            if (key) chatKeys.push(key);
        }
        const chatService = chatKeys.length > 0 ? new GeminiChatService(chatKeys) : null;
        console.log(`Loaded ${chatKeys.length} Gemini chat key(s)`);

        const groqKeys: string[] = [];
        for (let i = 1; i <= 5; i++) {
            const key = Deno.env.get(`GROQ_API_KEY_${i}`);
            if (key) groqKeys.push(key);
        }
        const singleGroqKey = Deno.env.get('GROQ_API_KEY');
        if (singleGroqKey && groqKeys.length === 0) groqKeys.push(singleGroqKey);
        const groqService = groqKeys.length > 0 ? new GroqService(groqKeys) : null;
        console.log(`Loaded ${groqKeys.length} Groq key(s)`);

        const { data: setting } = await supabase
            .from('system_settings').select('value').eq('key', 'ai_provider').single();
        const aiProvider = setting?.value || 'groq';
        console.log(`Using AI Provider: ${aiProvider}`);

        // Vector search + บันทึก embedding usage (index 21)
        let contextText = '';
        if (embeddingService) {
            const { values: embedding, success: embedSuccess } = await embeddingService.generateEmbedding(message);
            logGeminiUsage(supabase, EMBED_KEY_INDEX, GEMINI_EMBED_LIMIT, embedSuccess);

            if (embedding) {
                const { data: documents, error: matchError } = await supabase.rpc(
                    'match_troubleshooting_guide',
                    { query_embedding: embedding, match_threshold: 0.5, match_count: 5 }
                );
                if (!matchError && documents && documents.length > 0) {
                    contextText = documents.map((doc: any) =>
                        `หัวข้อ: ${doc.category} - ${doc.subcategory}\n` +
                        `อาการ: ${doc.symptom_description}\n` +
                        `สาเหตุ: ${doc.possible_causes}\n` +
                        `วิธีแก้: ${doc.solution}`
                    ).join('\n---\n');
                    console.log(`Found ${documents.length} relevant documents.`);
                } else {
                    if (matchError) console.error('Match error:', matchError);
                    else console.log('No relevant documents found.');
                }
            }
        }

        // Fallback text search
        if (!contextText) {
            const { data: textDocs } = await supabase
                .from('troubleshooting_guide').select('*')
                .textSearch('search_keywords', `'${message}'`, { type: 'websearch', config: 'english' })
                .limit(3);
            if (textDocs && textDocs.length > 0) {
                contextText = textDocs.map((doc: any) =>
                    `หัวข้อ: ${doc.category}\nอาการ: ${doc.symptom_description}\nวิธีแก้: ${doc.solution}`
                ).join('\n---\n');
                console.log(`Found ${textDocs.length} documents via text search.`);
            }
        }

        let responseText = '';

        if (aiProvider === 'gemini' && chatService) {
            const result = await chatService.chat(message, contextText);
            responseText = result.text;
            // บันทึก Gemini chat usage (index 11-15)
            logGeminiUsage(supabase, result.keyIndex + 10, GEMINI_CHAT_LIMIT, result.success);

        } else if (groqService) {
            const result = await groqService.chat(message, contextText);
            responseText = result.text;
            // บันทึก Groq usage (index 1-5)
            supabase.from('api_usage_logs').insert({
                api_key_index: result.keyIndex,
                requests_remaining: result.requestsRemaining,
                requests_limit: result.requestsLimit,
                tokens_remaining: result.tokensRemaining,
                tokens_limit: result.tokensLimit,
                reset_time: result.resetTime,
                timestamp: new Date().toISOString(),
            }).then(({ error }) => {
                if (error) console.error('Failed to log Groq usage:', error.message);
                else console.log(`Logged Groq key #${result.keyIndex}: ${result.requestsRemaining}/${result.requestsLimit} remaining`);
            });

        } else {
            responseText = 'ขออภัยครับ ไม่พบ API Key สำหรับ AI ในระบบ กรุณาตรวจสอบ Secrets ใน Supabase';
        }

        return new Response(
            JSON.stringify({ response: responseText }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
    } catch (error: any) {
        console.error('Error:', error);
        return new Response(
            JSON.stringify({ error: error.message }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
    }
});
