// utils/ollama_client.js (CommonJS 格式)
const axios = require('axios'); // 必須安裝 axios

// [!!! 請確認您的 Ollama 伺服器地址 !!!]
const OLLAMA_URL = 'http://localhost:11434/api/generate';

async function ollamaSummarize(modelName, text) {
    console.log(`[Ollama] 呼叫模型 ${modelName} 進行摘要...`);

    const prompt = `請根據以下新聞內容，嚴格按照 Modelfile 中 SYSTEM 提示詞的要求，生成事件摘要的 JSON 物件。\n\n新聞內容:\n\n${text}`;

    try {
        const response = await axios.post(OLLAMA_URL, {
            model: modelName,
            prompt: prompt,
            stream: false,
        });

        let jsonString = response.data.response.trim();

        // 清理 markdown 程式碼區塊標記 (例如 ```json...```)
        if (jsonString.startsWith('```json')) {
            jsonString = jsonString.substring(7).trim();
        }
        if (jsonString.endsWith('```')) {
            jsonString = jsonString.substring(0, jsonString.length - 3).trim();
        }

        const result = JSON.parse(jsonString);

        return { title: result.title || '', summary: result.summary || '' };

    } catch (error) {
        console.error(`Ollama 摘要呼叫失敗:`, error.message);
        // 拋出錯誤讓 Worker 知道任務失敗
        throw new Error(`Ollama 摘要模型 ${modelName} 失敗。`);
    }
}

module.exports = {
    ollamaSummarize
};