// scripts/build-event-modelfile.js (CommonJS 格式)
const fs = require('fs');
const path = require('path');

// --- 輸出路徑配置 ---
const SCRIPT_DIR = __dirname;
// 輸出路徑: 導向 customModules/model/
const OUTPUT_DIR = path.join(SCRIPT_DIR, '..', 'model');

// *** 關鍵變更點：使用新的檔案名稱 ***
const OUTPUT_FILENAME = 'eventSortingModelfile';

const OUTPUT_PATH = path.join(OUTPUT_DIR, OUTPUT_FILENAME);

// --- 模型設定內容 (SYSTEM PROMPT) ---
const systemPrompt = `
你是一個「事件整理與摘要（Event Sorting & Summarization）」模型。
任務：接收多則相關新聞的全文，輸出該事件的統一標題與整合摘要。

======================【一、輸出格式（唯一允許）】======================

你只能輸出一個 JSON 物件，格式固定為：

{
  "title": "事件的精確標題 (不超過 30 個中文字)",
  "summary": "整合所有新聞內容的摘要 (長度約 200-400 個中文字)"
}

規定：
1. 最終回答必須嚴格是「一個合法 JSON 物件」，不能有任何多餘文字、說明或註解。
2. 回答必須直接從左大括號 { 開始，以右大括號 } 結束。
3. 不能出現 markdown 程式碼區塊標記（例如 \`\`\`json\`\`\`）。

======================【二、內容整理規則】======================

1. 標題 (title): 簡潔、精確，控制在 30 個中文字以內。
2. 摘要 (summary): 整合所有新聞內容，著重於事件的發展順序，保持中立。
`;

// --- 組 Modelfile 內容 ---
const modelfileContent = `FROM qwen2.5:7b

PARAMETER temperature 0.3
PARAMETER top_p 0.6

SYSTEM """
${systemPrompt.trim()}
"""
`;

// --- 寫入檔案 ---
try {
    // 1. 確保 model 資料夾存在
    if (!fs.existsSync(OUTPUT_DIR)) {
        fs.mkdirSync(OUTPUT_DIR, { recursive: true });
        console.log(`✅ 創建資料夾: ${path.basename(OUTPUT_DIR)}`);
    }

    // 2. 寫入 Modelfile
    fs.writeFileSync(OUTPUT_PATH, modelfileContent);
    console.log(`✅ ${OUTPUT_FILENAME} 檔案建立成功!`);
    console.log(`位置: ${OUTPUT_PATH}`);
    console.log(`\n請使用指令 'ollama create eventsorting_model -f model/${OUTPUT_FILENAME}' 建立模型。`);
} catch (error) {
    console.error(`❌ 寫入 ${OUTPUT_FILENAME} 失敗:`, error.message);
}