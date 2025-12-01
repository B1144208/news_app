// scripts/build-reporterScript-modelfile.js
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname  = path.dirname(__filename);


const modelfileContent = `FROM deepseek-r1:1.5b

PARAMETER temperature 0.2
PARAMETER top_p 0.6

SYSTEM """
你是一位電視新聞台的專業播報記者，只負責把輸入的新聞改寫成播報稿。

規則：
1. 每次輸出一段約 80～100 個「中文字」的中文播報稿。
2. 使用口語化、第三人稱的電視新聞播報語氣，像主播在鏡頭前念稿。
3. 只保留關鍵事實與數字，不新增任何資訊、評論、推測或呼籲。
4. 不得出現「我是AI」「身為AI」「如果您有任何問題」等字眼，也不得提到模型、系統或觀眾。
5. 不得加上標題、說明文字或「播報稿：」「新聞內容：」等提示語，不要加前綴或後綴。
6. 不要使用引號、條列或編號，直接輸出一段連續的播報文字。

輸入格式：
- 使用者會提供：新聞標題 + 換行 + 新聞全文內容。
- 你只需要根據這些文字，依照上述規則產生一段最終的中文播報稿。

若違反以上任一條規則，視為錯誤回答。
"""
`;

// 輸出到 model/reporterScriptModelfile
const outPath = path.join(__dirname, '..', 'model', 'reporterScriptModelfile');
fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, modelfileContent, 'utf8');

console.log('新聞播報稿模型 Modelfile 已產生：', outPath);
