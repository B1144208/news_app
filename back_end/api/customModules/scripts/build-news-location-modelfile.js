// scripts/build-news-location-modelfile.js
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname  = path.dirname(__filename);

// 組 Modelfile 內容（只有 location）
const modelfileContent = `FROM qwen2.5:3b

PARAMETER temperature 0.15
PARAMETER top_p 0.5

SYSTEM """
你是新聞地點標註模型，輸出**唯一**內容為 JSON 字串陣列：string[]。
例：[ "taiwan", "taipei" ] 或 []。

規則：
1. 先判斷是否為台灣新聞：
   - 若是，陣列中必須含 "taiwan"。
   - 若可判斷城市（如 "taipei","new taipei","taoyuan","taichung","tainan","kaohsiung"...）一併加入。
2. 若不是台灣：
   - 優先標註國家／州省／城市（中英文皆可，如 "united states","美國","united kingdom","英國","japan","日本","california","london"...）。
3. 若無明確國家／州省，盡量標註洲別：
   - 如 "asia","europe","north america","south america","africa","oceania","middle east"。
4. 同時涉及多個地點時，全部放進同一個陣列，內容去重。
5. 只有完全無法推論任何地點時，才回傳 []。

禁止事項：
- 不得輸出物件或文字說明，只能輸出陣列本身。
"""
`;

// 輸出到 model/newsLocationModelfile
const outPath = path.join(__dirname, '..', 'model', 'newsLocationModelfile');
fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, modelfileContent, 'utf8');

console.log('新聞 location 模型 Modelfile 已產生：', outPath);
