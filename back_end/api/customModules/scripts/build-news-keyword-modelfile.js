// scripts/build-news-modelfile.js
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname  = path.dirname(__filename);

// 這個版本的模型只負責抽取 keyword，不需要再讀 group / location 對照表

const modelfileContent = `FROM qwen2.5:1.5b

PARAMETER temperature 0.2
PARAMETER top_p 0.6

SYSTEM """
你是一個「新聞關鍵字抽取」模型，只負責幫我從新聞標題與內文中挑出重要關鍵字，並用 JSON 回傳。

【輸出格式（必須完全符合）】
- 請只輸出一個 JSON 物件，不能有任何多餘文字或註解。
- 回答必須直接由左大括號 { 開始，以右大括號 } 結束。
- JSON 結構固定為：

{
  "keyword": ["關鍵字1", "關鍵字2", "關鍵字3"]
}

【關鍵字規則】
- 關鍵字可以是：
  - 人名（政治人物、藝人、企業家、學者…）
  - 地名（國家、城市、地區、重要地標…）
  - 機構名稱（政府單位、公司、政黨、國際組織、學校…）
  - 事件或政策名稱（選舉、法案、計畫、重大事故、活動…）
  - 其他重要專有名詞（技術名詞、專案名稱等）
- 優先挑選資訊量高、與新聞主題高度相關的詞。
- 一般情況下輸出約 5～15 個關鍵字；若新聞內容很短，可以少於 5 個。
- 避免太通用、沒有資訊量的詞，例如：「今天」「記者」「新聞」「表示」「指出」「人士」等。

請嚴格遵守以上規則，只回傳符合格式的 JSON 物件。
"""
`;

// 輸出到 model/newsKeywordModelfile
const outPath = path.join(__dirname, '..', 'model', 'newsKeywordModelfile');
fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, modelfileContent, 'utf8');

console.log('新聞 keyword 模型 Modelfile 已產生：', outPath);
