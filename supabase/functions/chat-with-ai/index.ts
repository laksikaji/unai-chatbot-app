<<<<<<< HEAD
// @ts-nocheck
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// --- GEMINI SERVICE CLASS ---
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

    async chat(prompt: string, context: string): Promise<string> {
        const apiKey = this.getRandomKey();

        // --- SYSTEM PROMPT (แก้ไขให้เป็นกลางแล้ว) ---
        const systemPrompt = `
คุณคือ "UNAi" ผู้ช่วย AI อัจฉริยะ

**บทบาทและหน้าที่ของคุณ:**
*   ตอบคำถามโดยอ้างอิงจากข้อมูลใน "CONTEXT" ที่ให้มาเท่านั้น
*   ช่วยเหลือในการแก้ไขปัญหา (Troubleshooting) ตามคู่มือที่มี
*   ให้บริการด้วยความสุภาพ และเป็นมืออาชีพ

**คำแนะนำในการตอบ:**
*   ใช้ข้อมูลจาก "CONTEXT" ด้านล่างนี้ในการตอบคำถามเป็นหลัก
*   ถ้าข้อมูลใน CONTEXT เพียงพอ ให้ตอบสรุปใจความสำคัญให้เข้าใจง่าย
*   ถ้าข้อมูลใน CONTEXT ไม่เพียงพอ หรือไม่เกี่ยวข้องกับคำถาม ให้ตอบว่า "ขออภัยครับ ฉันไม่มีข้อมูลเกี่ยวกับเรื่องนี้ในฐานข้อมูล" (ห้ามแต่งเรื่องเอง)
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
// ----------------------------

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
=======
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
>>>>>>> 58ed6caa9461429e61c2b34b485ebbe7bac64624
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
<<<<<<< HEAD
        const { message } = await req.json()

        // 1. Initial Setup
        const supabaseUrl = Deno.env.get('SUPABASE_URL')!
        const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
        const supabase = createClient(supabaseUrl, supabaseKey)

        // Load Secrets
        const groqApiKey = Deno.env.get('GROQ_API_KEY')

        // Load Multiple Gemini Keys
        const geminiKeys: string[] = [];
        for (let i = 1; i <= 5; i++) {
            const key = Deno.env.get(`GEMINI_API_KEY_${i}`);
            if (key) geminiKeys.push(key);
        }
        // Fallback to single key if multiple not found
        const singleGeminiKey = Deno.env.get('GEMINI_API_KEY');
        if (singleGeminiKey && geminiKeys.length === 0) geminiKeys.push(singleGeminiKey);

        const geminiService = geminiKeys.length > 0 ? new GeminiService(geminiKeys) : null;

        // 2. Load AI Provider Setting
        const { data: setting } = await supabase
            .from('system_settings')
            .select('value')
            .eq('key', 'ai_provider')
            .single()

        const aiProvider = setting?.value || 'groq' // Default to groq
        console.log(`Using AI Provider: ${aiProvider}`)

        // 3. Generate Embedding for User Query (Using Gemini)
        let contextText = ''
        if (geminiService) {
            const embedding = await geminiService.generateEmbedding(message)

            if (embedding) {
                // 4. Search in Database
                const { data: documents, error: matchError } = await supabase.rpc(
                    'match_troubleshooting_guide',
                    {
                        query_embedding: embedding,
                        match_threshold: 0.5, // ความเหมือนขั้นต่ำ (0-1)
                        match_count: 5 // จำนวนเอกสารที่ดึงมา
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

        // 5. Generate Response (Groq vs Gemini)
        if (aiProvider === 'gemini' && geminiService) {
            // --- Use Gemini ---
            responseText = await geminiService.chat(message, contextText);

        } else {
            // --- Use Groq (Default) ---
            // ถ้าไม่มี context จาก vector search ให้ลองหาแบบ text search ธรรมดา
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

            // สุ่ม Groq Key (ถ้ามีหลายตัว) - อันนี้สมมติใช้ตัวเดียวไปก่อน
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
                    model: 'llama3-70b-8192', // หรือรุ่นอื่นๆ
                    stream: false,
                }),
            })

            const data = await response.json()
            responseText = data.choices[0]?.message?.content || 'ขออภัยครับ ไม่สามารถเชื่อมต่อกับ Groq ได้'
        }

        // 6. Return Response
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
=======
        const { message, chatHistory } = await req.json()

        console.log('Received message:', message)

        if (!message) {
            return new Response(
                JSON.stringify({ error: 'Message is required' }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
        const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
        const supabase = createClient(SUPABASE_URL!, SUPABASE_SERVICE_KEY!)

        console.log('Searching database for:', message)

        const { data: searchResults, error: searchError } = await supabase
            .from('troubleshooting_guide')
            .select('*')
            .or(`search_keywords.ilike.%${message}%,category.ilike.%${message}%,symptom_description.ilike.%${message}%`)
            .limit(5)

        if (searchError) {
            console.error('Database search error:', searchError)
        }

        console.log(`Found ${searchResults?.length || 0} matching records`)

        const API_KEYS = [
            Deno.env.get('GROQ_API_KEY_1'),
            Deno.env.get('GROQ_API_KEY_2'),
            Deno.env.get('GROQ_API_KEY_3'),
            Deno.env.get('GROQ_API_KEY_4'),
            Deno.env.get('GROQ_API_KEY_5'),
        ].filter(key => key)

        if (API_KEYS.length === 0) {
            console.error('No GROQ_API_KEYs found')
            return new Response(
                JSON.stringify({ error: 'AI service not configured' }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        const GROQ_API_KEY = API_KEYS[Math.floor(Math.random() * API_KEYS.length)]
        console.log(`Using API Key ${API_KEYS.indexOf(GROQ_API_KEY) + 1}/${API_KEYS.length}`)

        let contextText = ''
        if (searchResults && searchResults.length > 0) {
            contextText = '\n\nข้อมูลจากฐานข้อมูล:\n\n'
            searchResults.forEach((result, index) => {
                contextText += `${index + 1}. ${result.category} - ${result.subcategory}\n`
                contextText += `   อาการ: ${result.symptom_description}\n`
                contextText += `   ตรวจสอบ: ${result.observation}\n`
                contextText += `   เช็คเบื้องต้น: ${result.initial_check}\n`
                contextText += `   สาเหตุที่เป็นไปได้: ${result.possible_causes}\n`
                contextText += `   วิธีแก้: ${result.solution}\n`
                contextText += `   ผู้รับผิดชอบ: ${result.responsible_party}\n`
                contextText += `   ที่มา: ${result.sheet_source}\n\n`
            })
        } else {
            contextText = '\n\nไม่พบข้อมูลที่ตรงกับคำถามในฐานข้อมูล\n'
        }

        console.log('Calling Groq API...')

        const systemPrompt = `คุณคือ UNAi Chatbot ผู้ช่วยวินิจฉัยและแก้ปัญหาระบบ UNAI

**คำเตือนสำคัญ:**
• **BLE มีแค่ Tag และ Anchor - ไม่มี Gateway เด็ดขาด**
• **UWB มี Tag, Anchor และ Gateway**
• **ถ้า user บอกคำตอบแล้ว → ข้ามไป อย่าถามซ้ำ**
• **ห้ามทบทวนข้อมูล** - ถามคำถามใหม่เลย สั้น ๆ
• **ห้ามบอกวิธีแก้ก่อนได้ข้อมูลครบทุกข้อ** - ต้องถามจนครบก่อน
• **BLE Tag หลายตัว + มีไฟ → ต้องถามสถานะ Anchor/Server ก่อนบอกวิธีแก้**
• **คำถามต้องตรงประเด็น รวดเร็ว**

---

**หลักการทำงาน:**

**ขั้นตอนที่ 1: รวบรวมข้อมูล (ถามแบบรวดเร็ว ตรงประเด็น)**

ข้อมูลที่ต้องได้:
1. ระบบ: BLE หรือ UWB
2. อุปกรณ์: Tag/Anchor/Gateway
3. อาการเฉพาะตามอุปกรณ์
4. จำนวน: ตัวเดียว/หลายตัว
5. สถานะไฟ LED
6. (ถ้า UWB + Tag) รุ่น Tag
7. **(สำคัญ) ถ้า BLE Tag หลายตัว + มีไฟ → ต้องถามสถานะ Anchor/Server**

**วิธีถามแบบใหม่ (รวดเร็ว ตรงประเด็น):**

**เมื่อรู้ BLE + Tag:**
→ ถามเลย: "Tag ไม่ขึ้นบน UI แค่ตัวเดียวหรือทุกตัวครับ?"
→ ถ้าตัวเดียว:
  - ถามต่อ: "Tag มีไฟกระพริบอยู่หรือไม่ครับ?"
  - ถ้าไม่มีไฟ → บอกวิธีแก้ (แบตหมด/Tag เสีย)
  - ถ้ามีไฟ → บอกวิธีแก้ (Tag เสีย)
→ ถ้าหลายตัว:
  - ถามต่อ: "Tag มีไฟกระพริบอยู่หรือไม่ครับ?"
  - ถ้าไม่มีไฟ → บอกวิธีแก้ (แบตหมดหมด/ไฟดับ)
  - **ถ้ามีไฟ → ต้องถามเพิ่ม:**
    1. "Anchor บริเวณนั้นแสดงสถานะ offline หรือไม่ครับ?"
    2. ถ้า offline → ไปถามเรื่อง Anchor (Icon สีเทา + ไฟ LED)
    3. ถ้าไม่ offline → ถาม "Server ออนไลน์หรือไม่ครับ?"
    4. เมื่อได้ข้อมูลครบแล้ว ถึงบอกวิธีแก้

**เมื่อรู้ BLE + Anchor:**
→ ถามเลย: "Anchor แสดงสถานะ offline แค่ตัวเดียวหรือหลายตัวครับ?"
→ แล้วถาม: "Icon ของ Anchor เป็นสีเทาหรือไม่ครับ?"
→ **ต้องถามไฟ LED แบบละเอียด (สำคัญมาก):**
  - ก่อน: "ไฟ LED เป็นสีอะไรครับ? (เขียว/แดง/ดับ)"
  - แล้ว: "ไฟกระพริบแบบไหนครับ?"
    * "ค้าง 2 วินาที แล้วกระพริบ 2 ครั้ง"
    * "ค้าง 2 วินาที แล้วกระพริบ 4 ครั้ง"  
    * "กระพริบเร็ว"
    * "กระพริบช้า"
    * "ติดค้าง"
→ **เมื่อได้ข้อมูลไฟ LED ครบแล้ว ถึงบอกวิธีแก้**

**เมื่อรู้ UWB + Tag:**
→ ถามก่อน: "เป็น Tag รุ่นไหนครับ? (Tag ธรรมดา / Tag Plus with 4G / Tag Plus with WiFi)"
→ แล้วถาม: "Tag ไม่ขึ้นบน UI แค่ตัวเดียวหรือทุกตัวครับ?"
→ ถ้าตัวเดียว:
  - ถามต่อ: "Tag มีไฟกระพริบอยู่หรือไม่ครับ?"
  - ถ้าไม่มีไฟ → บอกวิธีแก้ (แบตหมด/ชาร์จ/Tag เสีย)
  - ถ้ามีไฟ → บอกวิธีแก้ (Tag เสีย)
→ ถ้าทุกตัว:
  - ถามต่อ: "Tag มีไฟกระพริบอยู่หรือไม่ครับ?"
  - ถ้าไม่มีไฟ → บอกวิธีแก้ (แบตหมด/ไฟดับ)
  - **ถ้ามีไฟ → บอกวิธีแก้ (Gateway มีปัญหา → ดูหัวข้อ Gateway)**

**เมื่อรู้ UWB + Anchor:**
→ ถามเลย: "ใช้ Gateway หรือ Tag Plus ครับ?"
→ แล้วถาม: "Anchor offline แค่ตัวเดียวหรือหลายตัวครับ?"
→ แล้วถาม: "Anchor มีไฟกระพริบหรือไม่ครับ?"

**เมื่อรู้ UWB + Gateway:**
→ ถามเลย: "ไม่เห็น Tag/Anchor ทั้งโซน, ทั้งชั้น หรือทั้งไซท์ครับ?"
→ แล้วถาม: "สามารถ remote เข้า DWS ได้หรือไม่ครับ?"
→ แล้วถาม: "Gateway มีไฟกระพริบหรือไม่ครับ?"

**ตัวอย่างการสนทนาแบบใหม่:**

**กรณี BLE Tag ตัวเดียว:**
User: "มีปัญหา"
Bot: "ใช้ระบบ BLE หรือ UWB ครับ?"
User: "BLE"
Bot: "Tag หรือ Anchor ครับ?"
User: "Tag"
Bot: "Tag ไม่ขึ้นบน UI แค่ตัวเดียวหรือทุกตัวครับ?"
User: "ตัวเดียว"
Bot: "Tag มีไฟกระพริบอยู่หรือไม่ครับ?"
User: "ไม่มี"
Bot: "เข้าใจแล้วครับ จากอาการ Tag ตัวเดียวไม่ขึ้น UI และไม่มีไฟกระพริบ อาจเป็นได้ 2 กรณี:

**กรณีที่ 1: Tag แบตหมด**
วิธีแก้:
1. เปลี่ยนแบตเตอรี่ใหม่
2. ตรวจสอบหน้าเว็บ Tag ควรแสดงทันทีที่เริ่มทำงาน

**กรณีที่ 2: Tag มีปัญหา/เสีย**
วิธีแก้:
1. ปิด/เปิดใหม่
2. ตรวจสอบสถานะไฟควรกลับมากระพริบ
3. ถ้า Tag ยังไม่แสดงหน้าเว็บ แสดงว่า Tag อาจเสีย

คุณสามารถลองแก้เองได้ครับ หากยังไม่ได้ผล กรุณาติดต่อทีม UNAi"

**กรณี BLE Tag หลายตัว + มีไฟกระพริบ (สำคัญมาก - ต้องถามเพิ่ม):**
User: "Tag ไม่ขึ้น UI"
Bot: "ใช้ระบบ BLE หรือ UWB ครับ?"
User: "BLE"
Bot: "Tag หรือ Anchor ครับ?"
User: "Tag"
Bot: "Tag ไม่ขึ้นบน UI แค่ตัวเดียวหรือทุกตัวครับ?"
User: "หลายตัว"
Bot: "Tag มีไฟกระพริบอยู่หรือไม่ครับ?"
User: "มีไฟกระพริบ"
Bot: "Anchor บริเวณนั้นแสดงสถานะ offline หรือไม่ครับ?" ← **ต้องถามก่อนบอกวิธีแก้**
User: "offline ครับ"
Bot: "Icon ของ Anchor เป็นสีเทาหรือไม่ครับ?"
User: "ใช่"
Bot: "ไฟ LED เป็นสีอะไรครับ? (เขียว/แดง/ดับ)"
User: "เขียว"
Bot: "ไฟกระพริบแบบไหนครับ? (ค้าง 2 วิแล้วกระพริบ 2 ครั้ง / ค้าง 2 วิแล้วกระพริบ 4 ครั้ง / กระพริบเร็ว / กระพริบช้า / ติดค้าง)"
User: "กระพริบเร็ว"
Bot: "เข้าใจแล้วครับ จากอาการ Tag หลายตัวไม่ขึ้น UI มีไฟกระพริบ และ Anchor offline มีไฟเขียวกระพริบเร็ว:

**สาเหตุ: การเชื่อมต่อมายัง Server มีปัญหา**

วิธีแก้:
1. ตรวจสอบ Firewall/Internet Gateway
2. ติดต่อ Network Admin เพื่อตรวจสอบเครือข่าย
3. ติดต่อทีม UNAi เพื่อตรวจสอบ Server

กรุณาติดต่อ Network Admin ของคุณครับ หากยังไม่ได้ผล กรุณาติดต่อทีม UNAi"

**กรณี BLE Anchor (สำคัญมาก - ต้องถามไฟ LED ละเอียด):**
User: "Anchor offline"
Bot: "ใช้ระบบ BLE หรือ UWB ครับ?"
User: "BLE"
Bot: "Tag หรือ Anchor ครับ?"
User: "Anchor"
Bot: "Anchor แสดงสถานะ offline แค่ตัวเดียวหรือหลายตัวครับ?"
User: "บางตัว"
Bot: "Icon ของ Anchor เป็นสีเทาหรือไม่ครับ?"
User: "ใช่"
Bot: "ไฟ LED เป็นสีอะไรครับ? (เขียว/แดง/ดับ)"
User: "เขียว"
Bot: "ไฟกระพริบแบบไหนครับ? (ค้าง 2 วิแล้วกระพริบ 2 ครั้ง / ค้าง 2 วิแล้วกระพริบ 4 ครั้ง / กระพริบเร็ว / กระพริบช้า / ติดค้าง)"
User: "ค้าง 2 วิ แล้วกระพริบ 2 ครั้ง"
Bot: "เข้าใจแล้วครับ จากอาการ Anchor offline บางตัว Icon เป็นสีเทา และไฟเขียวค้าง 2 วิแล้วกระพริบ 2 ครั้ง:

**สาเหตุ: เครือข่าย Ethernet มีปัญหา**

วิธีแก้:
1. ตรวจสอบสาย Ethernet ที่เสียบ Anchor
2. ตรวจสอบ Switch/Router ที่ต่ออยู่
3. ติดต่อ Network Admin ของคุณเพื่อตรวจสอบเครือข่าย

กรุณาติดต่อ Network Admin ของคุณครับ"

---

**ขั้นตอนที่ 2: บอกวิธีแก้ (เมื่อได้ข้อมูลครบ)**

รูปแบบคำตอบ:

เข้าใจแล้วครับ จากอาการ [สรุปสั้น ๆ] อาจเป็นได้ [X] กรณี:

**กรณีที่ 1: [สาเหตุ]**
วิธีแก้:
1. [ขั้นตอนที่ 1]
2. [ขั้นตอนที่ 2]
3. [ขั้นตอนที่ 3]

**กรณีที่ 2: [สาเหตุ]**
วิธีแก้:
1. [...]

[ผู้รับผิดชอบ]

**วิธีแสดงผู้รับผิดชอบ:**
- ลูกค้า → "คุณสามารถลองแก้เองได้ครับ"
- SI/UNAi → "หากยังไม่ได้ผล กรุณาติดต่อทีม UNAi ครับ"
- ทั้งสอง → "ลองทำตามขั้นตอนดูก่อนครับ หากยังไม่ได้ผล กรุณาติดต่อทีม UNAi"

---

**กรณีพิเศษ:**

1. **ถ้าไม่มีข้อมูลในฐานข้อมูล:**
   → "อาการนี้ไม่ตรงกับที่มีในเอกสาร กรุณาติดต่อทีม UNAi โดยตรง"

2. **ถ้าข้อมูลยังไม่ครบ:**
   → **อย่าบอกวิธีแก้** ถามต่อจนครบก่อน

3. **ถ้ามีหลายกรณี:**
   → บอกทุกกรณีแยกชัดเจน

---

**ห้าม:**
• ทบทวนข้อมูลที่ user บอก
• **บอกวิธีแก้ก่อนได้ข้อมูลครบ** (เช่น Tag หลายตัวมีไฟ → ต้องถาม Anchor/Server ก่อน)
• **บอก "ดูหัวข้อ Anchor" หรือแนะนำให้ไปที่อื่น ก่อนถามไฟ LED (BLE Anchor)**
• ถาม Gateway เมื่อเป็น BLE
• ถามซ้ำเมื่อ user บอกแล้ว
• ใส่เลข 1. 2. 3. ในคำถาม
• พูดซ้ำซ้อน
• ใช้อิโมจิ

**ทำ:**
• **ถามตรงประเด็นทันที** (พอรู้อุปกรณ์ ถามอาการเฉพาะเลย)
• **BLE Tag หลายตัว + มีไฟ → ต้องถามสถานะ Anchor/Server ก่อนบอกวิธีแก้**
• **BLE Anchor ต้องถามไฟ LED แบบละเอียดก่อนบอกวิธีแก้** (สี + ลักษณะกระพริบ)
• **ถ้า user บอกแล้ว → ข้ามไปถามข้อถัดไป**
• **ถ้า user ถามกลับ → ตอบสั้น ๆ แล้วถามคำถามเดิมซ้ำ**
• **ถามประเภทอุปกรณ์ตามระบบ:**
  - BLE → "Tag หรือ Anchor ครับ?" (ห้ามถาม Gateway)
  - UWB → "Tag, Anchor หรือ Gateway ครับ?"
• UWB + Tag → ถามรุ่นก่อน
• บอกขั้นตอนชัดเจน
• แสดงผู้รับผิดชอบแบบนุ่มนวล
• ตอบภาษาไทย เป็นมิตร`

        const messages = [
            {
                role: 'system',
                content: systemPrompt + contextText
            }
        ]

        if (chatHistory && chatHistory.length > 0) {
            const recentHistory = chatHistory.slice(-12)
            recentHistory.forEach((msg: any) => {
                messages.push({
                    role: msg.isUser ? 'user' : 'assistant',
                    content: msg.content
                })
            })
        }

        messages.push({
            role: 'user',
            content: message
        })

        const groqResponse = await fetch(
            'https://api.groq.com/openai/v1/chat/completions',
            {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${GROQ_API_KEY}`,
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    model: 'llama-3.3-70b-versatile',
                    messages: messages,
                    temperature: 0.5,
                    max_tokens: 1024,
                    top_p: 0.9,
                }),
            }
        )

        if (!groqResponse.ok) {
            const errorText = await groqResponse.text()
            console.error('Groq API Error:', errorText)

            if (errorText.includes('rate_limit') || errorText.includes('Rate limit')) {
                console.error('RATE LIMIT EXCEEDED!')
                return new Response(
                    JSON.stringify({
                        error: 'ระบบใช้งานหนักเกินไป กรุณาลองใหม่ในอีกสักครู่',
                        details: 'Rate limit exceeded'
                    }),
                    { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                )
            }

            return new Response(
                JSON.stringify({ error: 'AI service error', details: errorText }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        const rateLimitRemaining = groqResponse.headers.get('x-ratelimit-remaining-requests')
        const rateLimitLimit = groqResponse.headers.get('x-ratelimit-limit-requests')
        const rateLimitReset = groqResponse.headers.get('x-ratelimit-reset-requests')
        const tokensRemaining = groqResponse.headers.get('x-ratelimit-remaining-tokens')
        const tokensLimit = groqResponse.headers.get('x-ratelimit-limit-tokens')

        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
        console.log('RATE LIMIT STATUS')
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
        console.log(`Requests: ${rateLimitRemaining}/${rateLimitLimit} remaining`)
        console.log(`Tokens:   ${tokensRemaining}/${tokensLimit} remaining`)
        console.log(`Resets at: ${rateLimitReset}`)

        if (rateLimitRemaining && rateLimitLimit) {
            const used = parseInt(rateLimitLimit) - parseInt(rateLimitRemaining)
            const usagePercent = (used / parseInt(rateLimitLimit) * 100).toFixed(1)
            console.log(`Usage: ${used}/${rateLimitLimit} (${usagePercent}%)`)

            if (parseInt(rateLimitRemaining) <= 3) {
                console.error('CRITICAL: Only', rateLimitRemaining, 'requests remaining!')
            } else if (parseInt(rateLimitRemaining) <= 10) {
                console.warn('WARNING: Only', rateLimitRemaining, 'requests remaining!')
            } else if (parseFloat(usagePercent) > 50) {
                console.log('INFO: Usage at', usagePercent + '%')
            } else {
                console.log('Healthy: Plenty of requests available')
            }
        }
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')

        const groqData = await groqResponse.json()
        console.log('Groq Response received')

        // บันทึก API Usage
        try {
            const rateLimitRemaining = groqResponse.headers.get('x-ratelimit-remaining-requests')
            const rateLimitLimit = groqResponse.headers.get('x-ratelimit-limit-requests')
            const tokensRemaining = groqResponse.headers.get('x-ratelimit-remaining-tokens')
            const tokensLimit = groqResponse.headers.get('x-ratelimit-limit-tokens')
            const rateLimitReset = groqResponse.headers.get('x-ratelimit-reset-requests')

            if (rateLimitRemaining && rateLimitLimit) {
                await supabase.from('api_usage_logs').insert({
                    api_key_index: API_KEYS.indexOf(GROQ_API_KEY) + 1,
                    requests_remaining: parseInt(rateLimitRemaining),
                    requests_limit: parseInt(rateLimitLimit),
                    tokens_remaining: parseInt(tokensRemaining || '0'),
                    tokens_limit: parseInt(tokensLimit || '0'),
                    reset_time: rateLimitReset
                })
            }
        } catch (logError) {
            console.error('Failed to log API usage:', logError)
            // ไม่ throw error เพราะไม่อยากให้การตอบคำถามล้มเหลว
        }

        const aiResponse = groqData.choices?.[0]?.message?.content ||
            'ขอโทษครับ ไม่สามารถสร้างคำตอบได้ในขณะนี้'

        console.log('AI Response:', aiResponse)

        return new Response(
            JSON.stringify({
                success: true,
                response: aiResponse,
                searchResults: searchResults?.length || 0
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
                error: error.message,
                success: false
            }),
            {
                status: 500,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
        )
    }
})
>>>>>>> 58ed6caa9461429e61c2b34b485ebbe7bac64624
