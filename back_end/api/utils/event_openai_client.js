// utils/event_openai_client.js

// 假設您的環境中已經配置或提供了 OpenAI API Key
const OPENAI_API_KEY = process.env.OPENAI_API_KEY || 'YOUR_OPENAI_API_KEY_HERE';
const OPENAI_URL = 'https://api.openai.com/v1/chat/completions';
const SUMMARIZE_MODEL = 'gpt-4o-mini'; // 摘要任務使用 gpt-4o-mini

/**
 * 使用 OpenAI 進行事件摘要和標題生成。
 * @param {string} modelName - 模型名稱 (此處將被 SUMMARIZE_MODEL 覆蓋)。
 * @param {string} userPrompt - 包含指令和新聞內容的提示詞。
 * @returns {Promise<{title: string, summary: string} | null>} 摘要結果物件或 null。
 */
async function openaiSummarize(modelName, userPrompt) {
    if (OPENAI_API_KEY === 'YOUR_OPENAI_API_KEY_HERE') {
        console.error("FATAL ERROR: 請在環境變數或程式碼中設定 OPENAI_API_KEY。");
        return null;
    }

    // 摘要模型的系統提示 (與您原有的 Modelfile 保持一致)
    const systemPrompt = `
        你是一個「事件整理與摘要（Event Sorting & Summarization）」模型。
        任務：接收多則相關新聞的全文，輸出該事件的統一標題與整合摘要。

        你的輸出必須嚴格是一個單一的 JSON 物件。
        格式必須為：{"title": "事件的精確標題", "summary": "整合所有新聞內容的摘要"}

        規定：
        1. 標題 (title) 必須簡潔、精確，不超過 30 個中文字。
        2. 摘要 (summary) 必須整合所有新聞內容，著重於事件的發展順序，保持中立，長度約 200-400 個中文字，且禁止複製貼上原文。
        3. 最終回答必須嚴格是「一個合法 JSON 物件」，不能有任何多餘文字、說明或註解。
    `;

    try {
        const response = await fetch(OPENAI_URL, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${OPENAI_API_KEY}`,
            },
            body: JSON.stringify({
                model: SUMMARIZE_MODEL,
                messages: [
                    { role: 'system', content: systemPrompt.trim() },
                    { role: 'user', content: userPrompt },
                ],
                // 強制 JSON 輸出
                response_format: { type: "json_object" },
                temperature: 0.3,
            }),
        });

        if (!response.ok) {
            const errorText = await response.text();
            console.error(`OpenAI API Error (${response.status}):`, errorText);
            throw new Error(`OpenAI API failed with status ${response.status}`);
        }

        const data = await response.json();

        // 解析 JSON 內容
        const jsonString = data.choices[0].message.content.trim();
        const result = JSON.parse(jsonString);

        if (!result.title || !result.summary) {
            console.error("OpenAI 輸出格式不正確:", result);
            return null;
        }

        return result;

    } catch (error) {
        console.error("[OpenAI Summarize Error]:", error.message);
        return null;
    }
}

module.exports = {
    openaiSummarize,
};