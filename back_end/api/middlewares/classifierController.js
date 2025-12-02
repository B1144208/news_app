const pool = require('../connect_db');
const { classifyNews } = require('../openai/classifierNews');
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

// 共用：呼叫 Ollama 的小幫手
async function callOllamaNewsModel (modelName, newsText, promptPrefix) {
  const ollamaRes = await fetch('http://localhost:11434/api/chat', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: modelName, 
      //format: 'json',
      stream: false,
      messages: [
        {
          role: 'user',
          content: `${promptPrefix}
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
  let result = ollamaData?.message?.content;

  // 1) content 是字串的話，先 parse 成 JSON
  if (typeof result === 'string') {
    const raw = result.trim();
    try {
      result = JSON.parse(raw);
    } catch (e) {
      //console.warn(modelName, 'parse JSON 失敗，原始內容：', raw);

      if (/^\[.*\]$/.test(raw)) {
        const inner = raw.slice(1, -1);
        result = inner
          .split(',')
          .map(s => s.trim())
          .filter(Boolean)
          .map(s => s.replace(/^['"]|['"]$/g, ''));
      } else {
        result = null;
      }
    }
  }
  
  // 2) 最後保險：一定要是陣列，不是就給 ["其他"]
  if (!Array.isArray(result)) {
    console.warn(modelName, '輸出不是陣列，fallback -> ["其他"]，實際輸出：', result);
    if(modelName="news-group") result = ['其他'];
    else result = [];
  }

  return result;   // 這裡保證是 string[]
}




// 1) group 分類：呼叫 news-group
async function newsGroupClassifier (req, res, next) {

  try {
    const { newsText } = req.body || {};

    if (!newsText || typeof newsText !== 'string') {
      return res.status(400).json({
        ok: false,
        error: 'newsText is required and must be a string'
      });
    }

    const result = await callOllamaNewsModel(
      'news-group',
      newsText,
      '請依照 SYSTEM 規則，對以下新聞判斷「group 主題分類」，只輸出 JSON 陣列：'
    );

    return res.json({
      ok: true,
      data: result
    });
  } catch (err) {
    console.error('newsGroupClassifier error:', err);
    return next(err);
  }
}

// 2) location 分類：呼叫 news-location
async function newsLocationClassifier (req, res, next) {
  try {
    const { newsText } = req.body || {};

    if (!newsText || typeof newsText !== 'string') {
      return res.status(400).json({
        ok: false,
        error: 'newsText is required and must be a string'
      });
    }

    const result = await callOllamaNewsModel(
      'news-location',
      newsText,
      '請依照 SYSTEM 規則，對以下新聞判斷「location 地理位置」，只輸出 JSON 陣列：'
    );

    return res.json({
      ok: true,
      data: result
    });
  } catch (err) {
    console.error('newsLocationClassifier error:', err);
    return next(err);
  }
}

// 3) keyword 抽取：呼叫 news-keyword
async function newsKeywordClassifier (req, res, next) {
  try {
    const { newsText } = req.body || {};

    if (!newsText || typeof newsText !== 'string') {
      return res.status(400).json({
        ok: false,
        error: 'newsText is required and must be a string'
      });
    }

    const result = await callOllamaNewsModel(
      'news-keyword',
      newsText,
      '請依照 SYSTEM 規則，從以下新聞抽取關鍵字，只輸出 JSON 陣列：'
    );

    return res.json({
      ok: true,
      data: result
    });
  } catch (err) {
    console.error('newsKeywordClassifier error:', err);
    return next(err);
  }
}



async function newsAllClassfier(req, res, next) {

  const { title, content } = req.body || {};

  const news = {
    title: title,
    content: content
  };

  const result = await classifyNews(news);
  return res.apiSuccess(result);
  console.log(result);
  // 可能輸出：
  // {
  //   group:    [ '生活', '天氣', '地方新聞', '氣象預報', ... ],
  //   location: [ 'taiwan', 'taipei' ],
  //   keyword:  [ '台北市', '大雨', '通勤', ... ]
  // }
}



// 如果你是用 module.exports
module.exports = {
  newsClassifier,
  newsAllClassfier,
  newsGroupClassifier,
  newsLocationClassifier,
  newsKeywordClassifier
};
