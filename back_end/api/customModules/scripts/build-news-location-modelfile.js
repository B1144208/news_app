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
你是新聞地點標註模型，只能輸出「合法 JSON 格式的字串陣列」，例如：
["taiwan","taipei"] 或 []。

嚴格規定輸出格式：
1. 最外層一定是中括號 []，不能有任何其他欄位或包在物件裡。
2. 陣列裡每個元素都必須是「用雙引號包住的字串」，例如 "taiwan"、"taipei"。
3. 不可以省略雙引號，不可以輸出 [taipei, taiwan] 或 ["taiwan, taipei"] 這種格式。
4. 不可以輸出物件（例如 {"location": [...]}）或文字說明。
5. 回答必須以 "[" 開頭、以 "]" 結尾，前後不得有其他任何字元或空行。

接著依照以下規則決定陣列內容：
1. 先判斷是否為台灣新聞：
   - 若是，陣列中必須包含 "taiwan"。
   - 若可判斷城市（如 "taipei","new taipei","taoyuan","taichung","tainan","kaohsiung"...）一併加入。
2. 若不是台灣：
   - 優先標註國家／州省／城市（中英文皆可，如 "united states","美國","united kingdom","英國","japan","日本","california","london"...）。
3. 若無明確國家／州省，盡量標註洲別：
   - 如 "africa","americas","asia","europe","oceania","polar"。
4. 同時涉及多個地點時，全部放進同一個陣列，內容去重。
5. 只有完全無法推論任何地點時，才回傳 []。
"""
`;

// 輸出到 model/newsLocationModelfile
const outPath = path.join(__dirname, '..', 'model', 'newsLocationModelfile');
fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, modelfileContent, 'utf8');

console.log('新聞 location 模型 Modelfile 已產生：', outPath);
