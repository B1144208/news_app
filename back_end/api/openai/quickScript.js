// quickScript.js
'use strict';

const client = require('../openaiClient');

// === SYSTEM：新聞快速播報稿 ===
const QUICK_SCRIPT_SYSTEM_PROMPT = `
你是「新聞快速播報稿」生成模型，負責將多則新聞改寫成適合語音播放的簡潔播報稿。

================ 輸出格式 ================
只輸出一個 JSON 物件，從 { 開始到 } 結束，不可有任何多餘文字、註解或程式碼區塊。

{
  "scripts": [
    "第一則新聞標題。內容大綱約200字。",
    "第二則新聞標題。內容大綱約200字。",
    ...
  ]
}

================ 改寫規則 ================
1. 每則新聞濃縮成一個字串，包含：
   - 新聞標題（保持簡潔有力）
   - 句號分隔
   - 內容大綱（控制在100字以內）

2. 內容大綱要求：
   - 只保留最核心資訊（人事時地物）
   - 用口語化、易聽懂的表達方式
   - 避免複雜句式和冗長描述
   - 數字使用中文表達（例如：三十萬、百分之五）
   - 去除不重要的細節和背景資訊

3. 語音播報優化：
   - 使用短句，避免過長的從句
   - 避免專業術語，用通俗說法
   - 標點符號適當，方便語音斷句
   - 保持資訊流暢，邏輯清晰

4. 陣列順序：
   - 按照輸入的新聞順序排列
   - 每則新聞獨立一個字串元素

================ 範例 ================
輸入：3則新聞的標題與內文
輸出：
{
  "scripts": [
    "台北市推動智慧交通新政策。市府宣布明年起在主要路口增設AI紅綠燈，預計減少塞車時間百分之二十，首波試辦區域包含信義區和大安區共三十個路口。",
    "半導體龍頭公布最新財報。營收創下單季新高達到五千億元，年增長百分之十五，主要受惠於AI晶片需求強勁，預計下季持續成長。",
    "強烈颱風接近台灣東部。氣象局發布海上警報，預計明天下午登陸，東部及北部地區將有豪大雨，各地方政府已啟動防災機制。"
  ]
}

重申：回答只能是上述格式的 JSON，不要多任何說明。
`;

// 你要用哪個 OpenAI 模型自己改，先預設 gpt-4.1-mini
const MODEL_FOR_QUICK_SCRIPT = 'gpt-4.1-mini';

// ===== 跟 classifyNews 一樣的小工具 =====

// 把 news 內文轉成 blocks：[{text}|{img:{src,alt}}...]
function normalizeBlocksFromNews(news) {
  if (Array.isArray(news?.text)) return news.text;
  if (Array.isArray(news?.content)) return news.content;

  const s = (news?.content ?? '').toString().trim();
  if (!s) return [];
  return [{ text: s }];
}

// 把 blocks 攤平成一大段文字
function flattenBlocksToPlainText(blocks) {
  if (!Array.isArray(blocks)) return '';
  return blocks
    .map(b => {
      if (!b || typeof b !== 'object') return '';
      if (typeof b.text === 'string') return b.text;
      if (b.img && typeof b.img.alt === 'string') return b.img.alt;
      return '';
    })
    .filter(Boolean)
    .join('\n');
}

/**
 * 快速播報稿
 * @param {Array|Object} newsList - 可以是一則新聞物件，或多則新聞的陣列
 * 每則格式建議：{ title: string, text?: string|blocks, content?: string|blocks }
 * @returns {Promise<{scripts: string[]}>}
 */
async function quickScriptModel(newsList) {
  // 允許傳單一物件進來
  const list = Array.isArray(newsList) ? newsList : [newsList];

  // 把多則新聞整理成一段 user prompt
  const mergedText = list
    .map((news, idx) => {
      const title  = news?.title ?? '';
      const blocks = normalizeBlocksFromNews(news);
      const body   = flattenBlocksToPlainText(blocks);

      return [
        `【第${idx + 1}則新聞】`,
        `標題：${title}`,
        `內文：${body}`
      ].join('\n');
    })
    .join('\n\n');

  const userContent = `以下是多則新聞的標題與內文，請依照 SYSTEM 規則產生 scripts JSON：\n\n${mergedText}`;

  const completion = await client.chat.completions.create({
    model: MODEL_FOR_QUICK_SCRIPT,
    temperature: 0.3,
    top_p: 0.7,
    messages: [
      { role: 'system', content: QUICK_SCRIPT_SYSTEM_PROMPT },
      { role: 'user', content: userContent }
    ]
  });

  const raw = completion.choices?.[0]?.message?.content?.trim?.() ?? '{}';

  let obj;
  try {
    obj = JSON.parse(raw);
  } catch (err) {
    console.error('[quickScriptModel] JSON parse error, raw =', raw);
    obj = {};
  }

  let scripts = [];
  if (Array.isArray(obj.scripts)) {
    scripts = obj.scripts
      .map(s => (s == null ? '' : String(s).trim()))
      .filter(Boolean);
  }

  return { scripts };
}

module.exports = {
  quickScriptModel
};
