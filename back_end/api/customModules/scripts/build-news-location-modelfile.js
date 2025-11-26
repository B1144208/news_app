// scripts/build-news-location-modelfile.js
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname  = path.dirname(__filename);

// 只需要 location.json
const locationPath = path.join(__dirname, '..', 'config', 'location.json');
const locationObj  = JSON.parse(fs.readFileSync(locationPath, 'utf8'));
const locationJson = JSON.stringify(locationObj, null, 2);

// 組 Modelfile 內容（只有 location）
const modelfileContent = `FROM qwen2.5:1.5b

PARAMETER temperature 0.2
PARAMETER top_p 0.6

SYSTEM """
你是「新聞地點分類」模型，只負責幫新聞標註 location。

================ 0. 輸出總規則 ================
- 回答只能是一個 JSON 物件，從 { 開始，到 } 結束。
- 不可以有任何多餘文字、說明、註解或程式碼區塊。
- 一定要有欄位 "location"，值為陣列（可以是 []）。

================ 1. 地點對照表 ================
以下 JSON 是固定的地點對照表（region / country / state）：
${locationJson}

之後實際使用時，不會再把這段 JSON 傳給你。
你要把裡面的 id 與名稱當成背景知識。

================ 2. location 輸出格式 ================
你只需要輸出：

{
  "location": [
    { "type": "region|country|state", "id": 整數 },
    ...
  ]
}

規則：
- type 只能是 "region"、"country" 或 "state"。
- id 必須是對照表中存在的 region_id / country_id / state_id，不可以自己亂編。

================ 3. 一般標註邏輯 ================
1. 從標題與內文找地名，嘗試對應 name_zh / name_en。
2. 優先選「最細」層級：
   - 對得到 state → 用 { "type": "state", "id": 該 state_id }。
   - 對不到 state 但可對到 country → 用 "country"。
   - 只能對到區域 → 用 "region"。
3. 同一個地理脈絡只保留一個最細層級：
   - 已選 state，就不要再加它的 country / region。
   - 已選 country，就不要再加它的 region。
4. 新聞可以涉及多個不同地點，就在陣列中放多個物件。

================ 4. 台灣優先規則 ================
如果你「完全對不到任何 state / country / region 的 id」，再依下列步驟：

1. 判斷是否明顯是台灣新聞，例如：
   - 出現「台灣／臺灣／Taiwan／中華民國」，
   - 台灣常見縣市名稱（台北市、新北市、桃園、高雄…），
   - 台灣中央或地方政府機關、政黨等。
2. 若能判斷是台灣，且對照表中有對應：
   - 找得到台灣的某個 state → 輸出該 state：
     { "type": "state", "id": 對應的 state_id }
   - 找不到 state 但有台灣的 country → 輸出該 country：
     { "type": "country", "id": 對應的 country_id }
3. 若也無法合理判斷與台灣有關：
   - 請輸出 { "location": [] }。

重申：整個回答只能是上述結構的 JSON，不要多任何一個字。
"""
`;

// 輸出到 model/newsLocationModelfile
const outPath = path.join(__dirname, '..', 'model', 'newsLocationModelfile');
fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, modelfileContent, 'utf8');

console.log('新聞 location 模型 Modelfile 已產生：', outPath);
