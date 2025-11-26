const pool = require('../connect_db');
const { checkRequireField } = require('../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');

async function newsClassifier (req, res, next) {
  try {
    // 1. 從 body 取新聞內容
    const { newsText } = req.body || {};

    if (!newsText || typeof newsText !== 'string') {
      return res.status(400).json({
        ok: false,
        error: 'newsText is required and must be a string'
      });
    }

    // 2. 呼叫本機 Ollama 的 news-classifier 模型
    const ollamaRes = await fetch('http://localhost:11434/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: 'news-classifier',
        format: 'json',     // ★ 強制模型只輸出 JSON
        stream: false,      // 一次拿完整結果，比較好處理
        messages: [
          {
            role: 'user',
            content: `請依照 SYSTEM 規則，對以下新聞進行分類，只輸出 JSON 物件：
【新聞內容】
${newsText}`
          }
        ]
      })
    });

    if (!ollamaRes.ok) {
      throw new Error(`Ollama returned status ${ollamaRes.status}`);
    }

    const ollamaData = await ollamaRes.json();
    // Ollama chat API 回傳格式大概是：
    // { model, created_at, message: { role, content }, done: true, ... }
    let result = ollamaData?.message?.content;

    // 有些情況 content 會是字串形式的 JSON，就再 parse 一次
    if (typeof result === 'string') {
      try {
        result = JSON.parse(result);
      } catch (e) {
        // 如果 parse 失敗，就維持原樣丟回去，前端自己檢查
      }
    }

    // 3. 回傳給前端
    return res.json({
      ok: true,
      data: result
    });
  } catch (err) {
    console.error('newsClassifier error:', err);
    // 丟給 Express 的錯誤處理 middleware
    return next(err);
  }
}

/*async function newsClassifier(req, res, next) {
  try {
    // 1. 從 body 拿新聞文字（標題＋內文）
    const { newsText } = req.body;

    if (!newsText || typeof newsText !== 'string') {
      return res.status(400).json({
        ok: false,
        error: '請在 body.newsText 傳入「新聞標題＋內文」的字串'
      });
    }

    // 2. 呼叫 Ollama 的 chat API，指定 format: 'json'
    const ollamaRes = await fetch('http://localhost:11434/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: 'news-classifier',
        format: 'json',   // ★ 要求模型只產生 JSON
        messages: [
          {
            role: 'user',
            content:
              '以下是一則新聞（標題與內文），' +
              '請完全依照 SYSTEM 規則進行分類，只輸出一個 JSON 物件：\n\n' +
              newsText      // ★ 這裡只放純新聞內容，不要再包含任何指令
          }
        ]
      })
    });

    if (!ollamaRes.ok) {
      const text = await ollamaRes.text().catch(() => '');
      return res.status(500).json({
        ok: false,
        error: '呼叫 Ollama 失敗',
        detail: text
      });
    }

    // 3. 解析 Ollama 回傳
    const ollamaJson = await ollamaRes.json();

    // Ollama chat 回傳格式大概長這樣：
    // { message: { role: 'assistant', content: '{ "group": ... }' }, ... }
    const rawContent = ollamaJson?.message?.content ?? '';

    let parsed;
    try {
      parsed = typeof rawContent === 'string'
        ? JSON.parse(rawContent)  // 內容是 JSON 字串 → parse 一次
        : rawContent;             // 如果未來 format 直接給物件也不會爆
    } catch (e) {
      // 如果模型沒照規矩給合法 JSON，就回 raw 給你 debug
      return res.status(500).json({
        ok: false,
        error: '模型回傳的內容不是合法 JSON',
        raw: rawContent
      });
    }

    // 4. 回傳給前端（只包一層 ok / data）
    return res.json({
      ok: true,
      data: parsed   // 這裡就是 { group: [...], location: [...], keyword: [...] }
    });
  } catch (err) {
    console.error('newsClassifier error:', err);
    return res.status(500).json({
      ok: false,
      error: 'newsClassifier server error'
    });
  }
}*/
module.exports = {
    newsClassifier
}