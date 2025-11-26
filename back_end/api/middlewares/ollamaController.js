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
module.exports = {
    newsClassifier
}