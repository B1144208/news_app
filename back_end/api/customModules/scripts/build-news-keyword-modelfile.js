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
你是「新聞關鍵字抽取」模型，只從新聞標題與內文中挑出重要關鍵字。

【輸出格式】
- 只能輸出一個 JSON 字串陣列（string[]），例如：
  ["關鍵字1","關鍵字2","關鍵字3"]
  或 []
- 回答必須以 [ 開頭、以 ] 結尾，中間為多個字串。
- 不可以輸出物件、註解、說明文字或程式碼區塊標記。

【怎麼選關鍵字】
- 優先選擇有資訊量、能代表新聞主題的詞，例如：
  人名、地名、機構名稱、事件/政策名稱、重要專有名詞等。
- 避免太普通的詞：例如「今天」「記者」「新聞」「表示」「指出」「人士」。
- 一般情況下約 5～15 個關鍵字；內容很短時可以更少。
- 若真的幾乎找不到合適關鍵字，可以回傳 []。

請嚴格遵守：整個回答只是一個合法的 JSON 字串陣列，不要多任何一個字。
"""
`;

// 輸出到 model/newsKeywordModelfile
const outPath = path.join(__dirname, '..', 'model', 'newsKeywordModelfile');
fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, modelfileContent, 'utf8');

console.log('新聞 keyword 模型 Modelfile 已產生：', outPath);
