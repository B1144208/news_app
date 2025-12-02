// classifyNews.js
'use strict';

const client = require('../openaiClient');

// === 3 個 SYSTEM prompt（分類用） ===

const GROUP_SYSTEM_PROMPT = `
你是一個「新聞主題標籤分類」模型。
任務：讀一則新聞（標題＋內文），從下面這份標籤清單中，挑選所有和新聞內容有關聯的標籤，並且只輸出一個 JSON 陣列。

可用標籤清單（固定，不可增加或修改）：

[
  "政治",
  "國際",
  "財經",
  "科技",
  "健康",
  "娛樂",
  "運動",
  "生活",
  "社會",
  "汽車",
  "房產",
  "天氣",
  "數位專題",
  "優惠",
  "政府政策",
  "選舉",
  "國會/立法院",
  "政黨動態",
  "外交/國防",
  "亞洲新聞",
  "歐美新聞",
  "兩岸關係",
  "戰爭/衝突",
  "國際政治/經濟",
  "股市",
  "匯率",
  "金融保險",
  "房地產",
  "就業與勞工",
  "創業與產業趨勢",
  "AI/人工智慧",
  "手機/電腦",
  "網路科技",
  "半導體/電子",
  "社群平台動態",
  "疾病/疫情",
  "醫療新聞",
  "心理健康",
  "養生保健",
  "醫療政策",
  "影視藝人",
  "綜藝節目",
  "韓流/日系藝人",
  "音樂",
  "八卦/緋聞",
  "棒球",
  "籃球",
  "足球",
  "奧運/國際賽事",
  "電競",
  "旅遊",
  "美食",
  "家居/裝潢",
  "時尚",
  "寵物/動物",
  "育兒",
  "命理/星座",
  "犯罪/法院",
  "意外/災難",
  "募捐/社福",
  "地方新聞",
  "校園事件",
  "新車發表",
  "試駕報導",
  "車展",
  "電動車",
  "汽車政策",
  "房市分析",
  "建案資訊",
  "不動產稅制",
  "區域開發",
  "氣象預報",
  "災害警報",
  "氣候變遷",
  "長篇專題",
  "數據新聞",
  "多媒體互動專題",
  "優惠情報",
  "好好買",
  "年度大促"
]

判斷原則：
1. 只要新聞內容和某個標籤「有明顯或合理的關聯」，就可以把那個標籤加進結果。
2. 同一則新聞可以有多個標籤，沒有上限。
3. 如果你無法判斷任何具體標籤，但這看起來仍是一則正常新聞，請輸出 ["其他"] 作為保底標籤。
4. 只有在文字幾乎完全無意義、像亂碼或極短內容時，才可以輸出 ["其他"]，而不是空陣列。

輸出格式（唯一允許）：
1. 你只能輸出一個「JSON 陣列」，內容是若干個字串，每個字串必須是上面清單中的其中一個，例如：
   ["政治","選舉","國會/立法院"]
2. 若有標籤可用，至少輸出一個以上的標籤字串。
3. 若真的無法對應任何特定標籤，請輸出：
   ["其他"]
4. 不可以輸出其他任何文字、說明、欄位名稱或多餘字元，不能包成物件。
5. 回答必須以 "[" 開頭，以 "]" 結尾。

記住：整個回答 = 一個 JSON 陣列，不能多任何一個字。
`;

const LOCATION_SYSTEM_PROMPT = `
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
`;

const KEYWORD_SYSTEM_PROMPT = `
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
`;

// === reporter（播報稿）SYSTEM：150–200 字 ===

const REPORTER_SYSTEM_PROMPT = `
你是一位電視新聞台的專業播報記者，只負責把輸入的新聞改寫成播報稿。

規則：
1. 每次輸出一段約 150～200 個「中文字」的中文播報稿。
2. 使用口語化、第三人稱的電視新聞播報語氣，像主播在鏡頭前念稿。
3. 只保留關鍵事實與數字，不新增任何資訊、評論、推測或呼籲。
4. 不得出現「我是AI」「身為AI」「如果您有任何問題」等字眼，也不得提到模型、系統或觀眾。
5. 不得加上標題、說明文字或「播報稿：」「新聞內容：」等提示語，不要加前綴或後綴。
6. 不要使用引號、條列或編號，直接輸出一段連續的播報文字。

輸入格式：
- 使用者會提供：新聞標題 + 換行 + 新聞全文內容。
- 你只需要根據這些文字，依照上述規則產生一段最終的中文播報稿。

若違反以上任一條規則，視為錯誤回答。
`;

// === chat（對話腳本）SYSTEM：150–200 字，JSON 陣列，每項 {speaker,text} ===

const CHAT_SYSTEM_PROMPT = `
你是一個專門把新聞改寫成「兩人對話腳本」的模型。

【輸出格式（唯一允許）】
- 只能輸出一個 JSON 陣列（array），內容是多個物件（object），每個物件格式必須完全符合：
  {"speaker": "A", "text": "......"}
  或
  {"speaker": "B", "text": "......"}
- 例如：
  [
    {"speaker": "A", "text": "XXXXXX"},
    {"speaker": "B", "text": "XXXXXX"},
    {"speaker": "A", "text": "XXXXXX"},
    {"speaker": "B", "text": "XXXXXX"}
  ]
- 最外層一定是中括號 []，裡面只能放物件，物件必須只有 speaker 與 text 兩個欄位。
- 回答必須以 "[" 開頭、以 "]" 結尾，不可以出現其他任何文字、註解、說明或程式碼區塊標記。

【內容規則】
1. 對話角色只有兩位：「A」與「B」，speaker 欄位只能是 "A" 或 "B"。
2. 依序交替發言，讓 A、B 來回對話數輪，整體總字數約 150～200 個「中文字」。
3. 對話內容要口語、自然，像朋友聊天，但要準確傳達新聞的重點事實，不添加新的事實或陰謀論。
4. 不得提到「我是AI」「模型」「系統」「觀眾」等字眼，也不要出現教學語氣。
5. 不要加標題、不要加前言或結語，整個回答只是一組 JSON 陣列。

輸入格式：
- 使用者會提供：新聞標題 + 換行 + 新聞全文內容。
- 你只需要根據這些文字，依照上述規則產生一組對話腳本（JSON 陣列）。
`;

// === translate（英翻中，單純字串）SYSTEM：英文 → 繁中 ===
const SIMPLE_TRANSLATE_SYSTEM_PROMPT = `
你是一個專門負責「英文 → 繁體中文」的翻譯模型。

規則：
1. 輸入會是一小段句子或一整段文章（可能是標題或內文），主要是英文。
2. 請翻譯成自然流暢的繁體中文，完整保留原本資訊與語氣，不要省略內容，也不要加入新的說明或註解。
3. 不要加上任何前綴或後綴文字、不要加引號，只輸出翻譯後的中文內容本身。
`;

// === 模型名稱 ===
const MODEL_FOR_GROUP     = 'gpt-4.1-mini';
const MODEL_FOR_LOCATION  = 'gpt-4.1-mini';
const MODEL_FOR_KEYWORD   = 'gpt-4.1-mini';
const MODEL_FOR_REPORTER  = 'gpt-4.1-mini';
const MODEL_FOR_CHAT      = 'gpt-4.1-mini';
const MODEL_FOR_TRANSLATE = 'gpt-4.1-mini';

/** 判斷字串是否「主要是中文」 */
function isMostlyChinese(str) {
  if (!str) return false;
  const han   = (str.match(/[\u4E00-\u9FFF]/g) || []).length;
  const latin = (str.match(/[A-Za-z]/g) || []).length;
  if (han === 0 && latin === 0) return false;
  return han >= latin;
}

/** 共用：呼叫 JSON 陣列模型（group/location/keyword） */
async function callJsonArrayModel({ systemPrompt, userContent, model, temperature, top_p }) {
  const completion = await client.chat.completions.create({
    model,
    temperature,
    top_p,
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: userContent }
    ]
  });

  const raw = completion.choices?.[0]?.message?.content?.trim?.() ?? '[]';

  let arr;
  try {
    arr = JSON.parse(raw);
  } catch (err) {
    console.error('JSON parse error, raw =', raw);
    arr = [];
  }

  if (!Array.isArray(arr)) return [];

  return Array.from(
    new Set(
      arr
        .map(x => (x == null ? '' : String(x).trim()))
        .filter(Boolean)
    )
  );
}

/** 共用：回傳一段文字（reporter 用） */
async function callTextModel({ systemPrompt, userContent, model, temperature, top_p }) {
  const completion = await client.chat.completions.create({
    model,
    temperature,
    top_p,
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: userContent }
    ]
  });

  return completion.choices?.[0]?.message?.content?.trim?.() ?? '';
}

/** 共用：回傳「物件陣列」格式的 JSON（chat 用） */
async function callJsonObjectArrayModel({ systemPrompt, userContent, model, temperature, top_p }) {
  const completion = await client.chat.completions.create({
    model,
    temperature,
    top_p,
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: userContent }
    ]
  });

  const raw = completion.choices?.[0]?.message?.content?.trim?.() ?? '[]';

  let arr;
  try {
    arr = JSON.parse(raw);
  } catch (err) {
    console.error('chat JSON parse error, raw =', raw);
    return [];
  }

  if (!Array.isArray(arr)) {
    console.error('chat result is not array, raw =', raw);
    return [];
  }

  return arr
    .filter(x => x && typeof x === 'object')
    .map(x => ({
      speaker: x.speaker === 'B' ? 'B' : 'A',
      text: (x.text ?? '').toString().trim()
    }))
    .filter(x => x.text);
}

/** 單段翻譯：英文 → 繁中（回傳字串） */
async function translateOneSegment(text) {
  const input = (text || '').trim();
  if (!input) return '';

  const completion = await client.chat.completions.create({
    model: MODEL_FOR_TRANSLATE,
    temperature: 0,
    top_p: 1,
    messages: [
      { role: 'system', content: SIMPLE_TRANSLATE_SYSTEM_PROMPT },
      { role: 'user', content: input }
    ]
  });

  return completion.choices?.[0]?.message?.content?.trim?.() ?? '';
}

/** translate：如果是英文就翻 title、text，回 {title,text}，否則回 null */
async function translateTitleAndTextIfNeeded(title, text) {
  const full = `${title}\n${text}`;
  if (isMostlyChinese(full)) {
    return null; // 原本就是中文，不翻
  }

  const [ttitle, ttext] = await Promise.all([
    translateOneSegment(title),
    translateOneSegment(text)
  ]);

  // 至少要有一個有東西才算成功，否則回 null
  if (!ttitle && !ttext) return null;

  return {
    title: ttitle || title,
    text : ttext || text
  };
}

/**
 * 對單一新聞做五種處理 + 英翻中
 * @param {Object} news
 * @param {string} news.title   - 新聞標題（可能是中或英）
 * @param {string} news.text    - 新聞內文字串（可能是中或英）
 * @returns {Promise<{
 *   group: string[],
 *   location: string[],
 *   keyword: string[],
 *   reporter: string,
 *   chat: {speaker:string, text:string}[],
 *   translate: null | {title:string, text:string}
 * }>}
 */
async function classifyNews(news) {
  const title = news?.title ?? '';
  const body  = news?.text ?? news?.content ?? '';

  const textForModel = `標題：${title}\n\n內文：${body}`;

  const [
    group,
    location,
    keyword,
    reporter,
    chat,
    translate
  ] = await Promise.all([
    // group
    callJsonArrayModel({
      systemPrompt: GROUP_SYSTEM_PROMPT,
      userContent: textForModel,
      model: MODEL_FOR_GROUP,
      temperature: 0.15,
      top_p: 0.5
    }),
    // location
    callJsonArrayModel({
      systemPrompt: LOCATION_SYSTEM_PROMPT,
      userContent: textForModel,
      model: MODEL_FOR_LOCATION,
      temperature: 0.15,
      top_p: 0.5
    }),
    // keyword
    callJsonArrayModel({
      systemPrompt: KEYWORD_SYSTEM_PROMPT,
      userContent: textForModel,
      model: MODEL_FOR_KEYWORD,
      temperature: 0.2,
      top_p: 0.6
    }),
    // reporter
    callTextModel({
      systemPrompt: REPORTER_SYSTEM_PROMPT,
      userContent: textForModel,
      model: MODEL_FOR_REPORTER,
      temperature: 0.2,
      top_p: 0.6
    }),
    // chat
    callJsonObjectArrayModel({
      systemPrompt: CHAT_SYSTEM_PROMPT,
      userContent: textForModel,
      model: MODEL_FOR_CHAT,
      temperature: 0.2,
      top_p: 0.6
    }),
    // translate（若為英文才翻）
    translateTitleAndTextIfNeeded(title, body)
  ]);

  return { group, location, keyword, reporter, chat, translate };
}

module.exports = {
  classifyNews
};
