const pool = require('../connect_db');
const { checkRequireField } = require('../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');
const { shortenArticle, cleanNewsScript } = require('../utils/scriptHelper');
const { execFile } = require('child_process');
const path = require('path');
const { searchNews } = require('./newsController');
const axios = require('axios');
const { getEmbedding } = require('../utils/embeddingHelper');


const OLLAMA_URL = 'http://localhost:11434/api/generate';
const OLLAMA_MODEL = 'qwen2.5:1.5b';

/*
@ general, reporter, chat: 給予一個 List {"id", "title", "text"}
@ general: 僅 news_body
@ reporter: 記者播報
@ chat: 聊天對白
@
*/

async function getText (req, res, next) {
    let { id, idList } = req.query ?? {}

    /*try {
      [ id, idList ] = await checkRequireField ([
        { field: 'id'     , data: id      , type: 'number'  , other: ['lth'] },
        { field: 'idList' , data: idList  , type: 'array'   , other: ['lth'], array_filter: 'number' }
      ]);
    } catch (err) {
      err.desc = "middlewares-updateGroupOrder(): Missing or Invalid required fields";
      return next(err);
    }*/

    fakeReq = {
      query: { mode: "complex" },
      body: { id: idList}
    }
    try {
      let result = await callAndCatchApiSuccess(searchNews, fakeReq);
      result = result.complexList.map(item => {
        const bodyText = (item.newsBody || [])
          .filter(part => typeof part.text === 'string' && part.text.trim() !== '')
          .map(part => part.text.trim())
          .join('\n');

        return {
          id: item.newsId,
          title: item.newsTitle,
          text: bodyText
        }
      });
      return res.apiSuccess(result, "Search Success");
    } catch (err) {
      err.desc = "middlewares-scriptController(): error";
      return next(err);
    }
}

async function getReporterChatText(idList) {
  // 若沒有 id，直接回傳空陣列
  if (!Array.isArray(idList) || idList.length === 0) {
    return [];
  }

  const sql = `
    SELECT
      nd.news_id,
      nd.reporter_script,
      nc.chat_speaker,
      nc.chat_text,
      nc.chat_order
    FROM news_data AS nd
    LEFT JOIN news_chat AS nc
      ON nc.news_id = nd.news_id
    WHERE nd.news_id IN (?)
    ORDER BY nd.news_id ASC, nc.chat_order ASC;
  `;
  const params = [idList];

  try {
    const [rows] = await pool.query(sql, params);

    // 用 Map 依 news_id 分組
    const map = new Map();

    for (const row of rows) {
      const id = row.news_id;

      if (!map.has(id)) {
        map.set(id, {
          id,
          reporter: row.reporter_script || null,
          chat: []
        });
      }

      // 如果 news_chat 還沒有資料（LEFT JOIN 回來可能是 null），就不要 push
      if (row.chat_speaker != null || row.chat_text != null) {
        map.get(id).chat.push({
          speak: row.chat_speaker,
          text: row.chat_text
        });
      }
    }

    // 如果某些 id 在 news_chat 完全沒有資料，上面的迴圈不會建立，
    // 但你可能仍希望它們出現在結果中，所以另外補齊：
    for (const id of idList) {
      if (!map.has(id)) {
        // 重新查 rows 找對應 reporter_script
        const row = rows.find(r => r.news_id === id);
        map.set(id, {
          id,
          reporter: row ? row.reporter_script : null,
          chat: []
        });
      }
    }

    return Array.from(map.values());
  } catch (err) {
    console.error('[getReporterChatText] database search error:', err);
    throw err;
  }
}


async function getIdList() {
  let sql = `
    SELECT DISTINCT nd.news_id
    FROM news_data AS nd
    LEFT JOIN news_task AS nt ON nt.news_id = nd.news_id
    WHERE nt.news_id IS NULL OR (nt.reporter_script = 1 AND nt.chat_script = 1)
    ORDER BY nd.created_at DESC
    LIMIT 100;
  `;
  try {
    let [row] = await pool.query(sql);
    return row.map(r => r.news_id);
  } catch (err) {
    console.error("[getIdList] database search error")
  }
}


// 取得 一般朗讀 + 新聞播報 + 聊天對白 腳本
async function getScript(req, res, next) {

  // 取得播放順序
  let idList;
  try {
    idList = await getIdList();
  } catch (err) {
    err.desc = "middlewares-generalScript(): getIdList() Error";
  }

  let general = await getText(idList);
  let reporterchat = await getReporterChatText(idList);
  
  // 先把兩組資料轉成 Map，方便用 id 找
  const generalMap = new Map(general.map(g => [g.id, g]));
  const reporterMap = new Map(reporterchat.map(r => [r.id, r]));

  // 依照 idList 的順序組合結果
  const result = idList.map(id => {
    const g = generalMap.get(id) || {};
    const r = reporterMap.get(id) || {};

    return {
      id,
      title:    g.title     || '',
      general:  g.text      || '',       // 把 text 變成 general
      reporter: r.reporter  || '',
      chat:     r.chat      || ''        // 如果你想要陣列可改成 r.chat || []
    };
  });

  // 如果需要回傳：
  return res.apiSuccess(result, "get scripts success");
}

// 製作 新聞播報 腳本
async function reporterMake(req, res, next) {
  

}

// 製作 聊天對白 腳本
async function chatMake(req, res, next) {
  

}

/*async function generalScript(req, res, next) {
    let { id, idList, times, limit } = req.query ?? {}

    try {
      [ id, idList, times, limit ] = await checkRequireField ([
        { field: 'id'     , data: id      , type: 'number'  , other: ['lth'] },
        { field: 'idList' , data: idList  , type: 'array'   , other: ['lth'], array_filter: 'number' },
        { field: 'times'  , data: times   , type: 'number'  , other: ['non_null'] , default: 1},
        { field: 'limit'  , data: limit   , type: 'number'  , other: ['non_null'] , default: 300}
      ]);
    } catch (err) {
      err.desc = "middlewares-updateGroupOrder(): Missing or Invalid required fields";
      return next(err);
    }

    // 沒有 idList，呼叫 searchNews 得到 idList
    if ( !idList ) {
      if (id ) idList = [id];
      else idList = [];
      let fakeReq = {
        query: { mode: "id" , limit: limit},
        body: {}
      }
      try {
        let result = await callAndCatchApiSuccess(searchNews, fakeReq);
        idList.push(...(result?.idList || []));
        //return res.apiSuccess(result, "Search Success");
      } catch (err) {
        err.desc = "middlewares-generalScript(): error";
        return next(err);
      }
    }

    fakeReq = {
      query: { mode: "complex" },
      body: { id: idList}
    }
    try {
      let result = await callAndCatchApiSuccess(searchNews, fakeReq);

      result = result.complexList.map(item => {
        const bodyText = (item.newsBody || [])
          .filter(part => typeof part.text === 'string' && part.text.trim() !== '')
          .map(part => part.text.trim())
          .join('\n');

        return {
          id: item.newsId,
          title: item.newsTitle,
          text: bodyText
        }
      });
      return res.apiSuccess(result, "Search Success");
    } catch (err) {
      err.desc = "middlewares-scriptController(): error";
      return next(err);
    }
}*/

/*async function reporterScript(req, res, next) {
    let { id } = req.params ?? {}
    // 交給 generalScript 生成的一組id及text，用deepseek 產生 reporterScript

    // 1️⃣ 先呼叫 generalScript 拿原始 {id,title,text}
    let fakeReq = {
      params: {id: id}
    }
    let generalScriptResult;
    try {
      generalScriptResult = await callAndCatchApiSuccess(generalScript, fakeReq);
      //return res.apiSuccess(generalScriptResult);
    } catch (err) {
      err.desc = "middlewares-reporterScript(): call generalScript error";
        return next(err);
    }
    
    try {
    // 2️⃣ 取得裡面的陣列：可能是 result 或 result.list
    const items = Array.isArray(generalScriptResult)
      ? generalScriptResult
      : generalScriptResult.list ?? [];

    // 3️⃣ 對每一筆丟給 DeepSeek 產生播報稿
    const reporterItems = await Promise.all(
      items.map((item) =>
        callDeepseekReporterScript({
          id: item.id,
          title: item.title,
          text: shortenArticle(item.text)
        }),
      ),
    );

    // 4️⃣ 組回輸出的格式
    let output;
    if (Array.isArray(generalScriptResult)) {
      // 原本就是陣列 → 直接回陣列
      output = reporterItems;
    } else {
      // 原本是物件（例如 { list, total, ... }）→ 保留其它欄位，只把 list 換掉
      output = {
        ...generalScriptResult,
        list: reporterItems,
      };
    }

    return res.apiSuccess(output);
  } catch (err) {
    err.desc = 'middlewares-reporterScript(): call deepseek error';
    return next(err);
  }
}*/


// ---- reporter ----
/*async function reporterScriptFast(req, res, next) {
    let { id, times } = req.params ?? {}
    // 交給 generalScript 生成的一組id及text，用deepseek 產生 reporterScript

    // 1️⃣ 先呼叫 generalScript 拿原始 {id,title,text}
    let fakeReq = {
      params: {id: id}
    }
    let generalScriptResult;
    try {
      generalScriptResult = await callAndCatchApiSuccess(generalScript, fakeReq);
      //return res.apiSuccess(generalScriptResult);
    } catch (err) {
      err.desc = "middlewares-reporterScript(): call generalScript error";
        return next(err);
    }
    
    try {
    // 2️⃣ 取得裡面的陣列：可能是 result 或 result.list
    const items = Array.isArray(generalScriptResult)
      ? generalScriptResult
      : generalScriptResult.list ?? [];

    // 3️⃣ 對每一筆丟給 DeepSeek 產生播報稿
    const reporterItems = await Promise.all(
      items.map((item) =>
        callDeepseekReporterScript({
          id: item.id,
          title: item.title,
          text: shortenArticle(item.text)
        }),
      ),
    );

    // 4️⃣ 組回輸出的格式
    let output;
    if (Array.isArray(generalScriptResult)) {
      // 原本就是陣列 → 直接回陣列
      output = reporterItems;
    } else {
      // 原本是物件（例如 { list, total, ... }）→ 保留其它欄位，只把 list 換掉
      output = {
        ...generalScriptResult,
        list: reporterItems,
      };
    }

    return res.apiSuccess(output);
  } catch (err) {
    err.desc = 'middlewares-reporterScript(): call deepseek error';
    return next(err);
  }
}*/





























// ---- chat ----
/*async function chatScript(req, res, next) {
    let { id } = req.params ?? {}
    // 交給 generalScript 生成的一組id及text，用deepseek 產生 chatScript
    return;
}

// ---- quick ----
async function quickScript(req, res, next) {
    // 用熱度高id直接生成一組id
    return;
}*/




async function callDeepseekReporterScript({ id, title, text }) {

  // 組 prompt：請 DeepSeek 幫忙改寫成 80~100 字的播報稿
  /*const prompt =
    '你是一位台灣電視新聞台的記者，請根據以下新聞標題與全文內容，' +
    '撰寫一段約 80 到 100 字的中文播報稿。\n\n' +
    '要求：\n' +
    '1. 保留主要事實與數據，刪去重複內容。\n' +
    '2. 使用口語化、第三人稱播報語氣。\n' +
    '3. 不要加入新的資訊，也不要加標題或說明文字，只輸出播報稿內容本身。\n' +
    '4. 不要說自己是 AI 或模型，不要回答提問，不要給任何建議或安全聲明（例如「如果您有任何問題」等）。\n' +
    '5. 不要輸出「播報稿：」「新聞播報：」等提示語，只輸出內容。\n\n' +
    '【標題】\n' + title + '\n\n' +
    '【內文】\n' + text + '\n\n' +
    '【請開始撰寫播報稿】';
  */

  const system = 
    '你是一位電視新聞台的專業播報記者，只負責把輸入的新聞改寫成播報稿。\n' +
    '規則：\n' +
    '1. 每次輸出一段 80~100 個字的中文播報稿。\n' +
    '2. 用口語化、第三人稱的電視新聞播報語氣。\n' +
    '3. 只保留關鍵事實與數字，不新增任何資訊或評論。\n' +
    '4. 不得出現「我是AI」「身為AI」「如果您有任何問題」等類似字句。\n' +
    '5. 不得加上標題、說明文字或「播報稿：」「新聞內容：」等提示語。\n' +
    '若違反以上任一條規則，視為錯誤回答。';
  const prompt = 
    title + '\n' +
    text + '\n\n' +
    '請依規則產生播報稿。';
  /*const prompt =
    '將下列新聞改寫成約 60 到 80 字的中文電視新聞播報稿。' +
    '口語化、第三人稱，只保留關鍵事實與數字，不新增資訊或評論，' +
    '不要加標題或說明文字，也不要提到自己或 AI 身分。\n\n' +
    '【標題】\n' + title + '\n\n' +
    '【內文】\n' + text + '\n\n' +
    '請直接輸出播報稿內容。';*/
  
  const start = Date.now();
  const payload = {
    model: OLLAMA_MODEL,
    system,
    prompt,
    stream: false,
    options: {
      num_predict: 256
    },
  };

  let resp;
  try {
    resp = await axios.post(OLLAMA_URL, payload, {
      headers: { 'Content-Type': 'application/json' },
      //timeout: 5000, // ⏱ 最多給 5 秒，超過就丟錯
    });
  } catch (err) {
    // 這裡是「思考超過 5 秒」或其他連線錯誤的處理
    if (err.code === 'ECONNABORTED') {
      // timeout
      console.error(`DeepSeek timeout: reporterScript id=${id}`);
    } else {
      console.error(`DeepSeek error: reporterScript id=${id}`, err.message);
    }
    // 讓外層的 try/catch 處理這個錯誤
    throw err;
  }

  let script = resp.data?.response || '';

  script = cleanNewsScript(script);

  console.log('deepseek latency(ms):', Date.now() - start);

  // 回傳保持 {id, title, text} 結構，只把 text 換成播報稿
  return {
    id,
    title,
    text: script,
  };
}














































// ---- call ask.sh ----
async function callAskScript(req, res, next) {
  try {
    const { question } = req.body;
    const scriptPath = path.join(__dirname, "../ask.sh"); // 指向 ask.sh 檔案

    execFile("bash", [scriptPath, question], (error, stdout, stderr) => {
      if (error) {
        console.error("執行 ask.sh 出錯：", stderr);
        return res.status(500).json({ error: "Failed to execute ask.sh" });
      }

      const response = stdout.trim();
      res.json({ response });
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to execute ask.sh" });
  }
}

// ---- 匯出所有函式 ----
module.exports = {
  getText,
  getScript,
  reporterMake,
  chatMake,
//quickScript,
  callAskScript
};
