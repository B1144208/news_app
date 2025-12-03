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
const QUICK_SCRIPT_MODEL = 'quick-script'; // 快速播放專用 model

/*
@ general, reporter, chat: 給予一個 List {"id", "title", "text"}
@ general: 僅 news_body
@ reporter: 記者播報
@ chat: 聊天對白
@
*/

async function getText (req, res, next) {
    let { idList } = req.query ?? {}
    const origin_body = req.query?.origin_body !== undefined;

    fakeReq = {
      query: { mode: "complex" },
      body: { id: idList}
    }
    try {
      let result = await callAndCatchApiSuccess(searchNews, fakeReq);
      result = result.complexList.map(item => {
        if (origin_body) {
          return {
            id: item.newsId,
            title: item.newsTitle,
            text: item.newsBody
          };
        }
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

/**
 * 從 news/text 結構中生出 blocks
 * 目前假設：
 * - news.text 是 [{text}, {img:{src,alt}}, ...]
 * - 或 news.content 是同樣格式
 * - 如果只是純字串 content，就包成 [{text: content}]
 */
function normalizeBlocksFromNews(news) {
  if (Array.isArray(news?.text)) return news.text;
  if (Array.isArray(news?.content)) return news.content;

  const s = (news?.content ?? '').toString().trim();
  if (!s) return [];
  return [{ text: s }];
}

/** 把 blocks 攤平成純文字（給 LLM 用） */
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

/** 判斷字串是否「主要是中文」：中文字 >= 英文字母就算中文 */
function isMostlyChinese(str) {
  if (!str) return false;
  const han   = (str.match(/[\u4E00-\u9FFF]/g) || []).length;
  const latin = (str.match(/[A-Za-z]/g) || []).length;
  if (han === 0 && latin === 0) return false;
  return han >= latin;
}

/**
 * 從 DB 裡補上 reporter_script & news_chat
 * @param {number[]} idList
 * @param {Map<number, Object>} scriptById  // id -> {id,title,general,reporter,chat}
 */
async function loadReporterAndChatForIds(idList, scriptById) {
  if (!Array.isArray(idList) || !idList.length) return;

  const ph = idList.map(() => '?').join(',');
  const params = idList;

  // 1) reporter_script
  const sqlReporter = `
    SELECT news_id, reporter_script
    FROM news_data
    WHERE news_id IN (${ph})
      AND reporter_script IS NOT NULL
      AND reporter_script <> ''
  `;
  const [rowsReporter] = await pool.query(sqlReporter, params);

  for (const row of rowsReporter) {
    const entry = scriptById.get(row.news_id);
    if (entry && !entry.reporter) {
      entry.reporter = row.reporter_script;
    }
  }

  // 2) news_chat
  const sqlChat = `
    SELECT
      news_id,
      chat_speaker AS speaker,
      chat_text    AS text,
      chat_order
    FROM news_chat
    WHERE news_id IN (${ph})
    ORDER BY news_id, chat_order
  `;
  const [rowsChat] = await pool.query(sqlChat, params);

  const chatGrouped = new Map();
  for (const row of rowsChat) {
    if (!chatGrouped.has(row.news_id)) {
      chatGrouped.set(row.news_id, []);
    }
    chatGrouped.get(row.news_id).push({
      speaker: row.speaker,
      text: row.text
    });
  }

  for (const [newsId, chatArr] of chatGrouped) {
    const entry = scriptById.get(newsId);
    if (entry && (!entry.chat || !entry.chat.length)) {
      entry.chat = chatArr;
    }
  }
}

/**
 * SSE：一個一個把 {id,title,general,reporter,chat} 丟給前端
 * 流程：
 * 1. 從 body 取 idList
 * 2. 用 getText 拿 {id,title,general}
 * 3. 查 DB 拿 reporter_script & news_chat，組成 scriptMap
 * 4. 沒有 reporter/chat 的再組一個 pendingIds 丟給 runAllWorker(idList)
 * 5. 從 scriptMap 第一筆開始找「已經完整」的，遇到缺的就停，每 3 秒重查 DB
 * 6. 一旦某筆補齊就立刻 res.write 丟出去
 */
async function getScript(req, res, next) {
  try {
    // 1) 取得 idList
    let { idList } = req.body || {};

    if (!Array.isArray(idList) || !idList.length) {
      return res.status(400).json({
        ok: false,
        error: 'idList is required and must be a non-empty array'
      });
    }

    // 整理成整數 & 去重
    idList = Array.from(
      new Set(
        idList
          .map(x => Number(x))
          .filter(x => Number.isInteger(x) && x > 0)
      )
    );

    if (!idList.length) {
      return res.status(400).json({
        ok: false,
        error: 'idList is empty after normalization'
      });
    }

    // 2) getText 取得基本 script（假設回傳 [{id,title,general}, ...]）
    let baseList;
    try {
      // ⚠️ 依你實際的 getText 介面調整：
      //   如果是 getText(idList) 就這樣；如果是 getText({idList}) 就改。
      baseList = await getText(idList);
    } catch (err) {
      err.desc = 'getText() failed in getScript';
      throw err;
    }

    // 建立 scriptMap & map 索引：保持 idList 的順序
    const scriptMap = [];
    const scriptById = new Map();

    for (const id of idList) {
      const base = Array.isArray(baseList)
        ? baseList.find(x => Number(x.id) === id)
        : null;

      const entry = {
        id,
        title: base?.title || '',
        general: base?.general || '',
        reporter: null,
        chat: null
      };

      scriptMap.push(entry);
      scriptById.set(id, entry);
    }

    // 3) 先查一次 DB，補上已經有的 reporter_script / news_chat
    await loadReporterAndChatForIds(idList, scriptById);

    // 4) 找出還缺 reporter 或 chat 的 idList
    const pendingIds = scriptMap
      .filter(it => !it.reporter || !it.chat || !it.chat.length)
      .map(it => it.id);

    // 5) 把 pendingIds 丟給 runAllWorker（背景慢慢跑，負責寫 DB）
    if (pendingIds.length) {
      // 不 await，讓它在背景跑
      runAllWorker(0, pendingIds).catch(err => {
        console.error('runAllWorker error in getScript:', err);
      });
    }

    // ========= 設定 SSE / chunked response =========
    res.setHeader('Content-Type', 'text/event-stream; charset=utf-8');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    if (res.flushHeaders) res.flushHeaders();

    let currentIndex = 0;
    let timer = null;
    let ended = false;

    function sendItem(entry) {
      const payload = {
        type: 'item',
        newsId: entry.id,
        title: entry.title,
        general: entry.general,
        reporter: entry.reporter,
        chat: entry.chat
      };
      res.write(`data: ${JSON.stringify(payload)}\n\n`);
    }

    function sendDone() {
      if (ended) return;
      ended = true;
      res.write(`data: ${JSON.stringify({ type: 'done' })}\n\n`);
      res.end();
      if (timer) clearInterval(timer);
    }

    // 檢查 scriptMap[currentIndex..]，把「連續 ready 的」通通丟出去
    async function tryFlushReady() {
      while (currentIndex < scriptMap.length) {
        const item = scriptMap[currentIndex];
        const ready =
          item &&
          item.reporter &&
          item.reporter.toString().trim() &&
          Array.isArray(item.chat) &&
          item.chat.length > 0;

        if (!ready) break;

        sendItem(item);
        currentIndex++;
      }

      if (currentIndex >= scriptMap.length) {
        // 全部送完
        sendDone();
        return true;
      }
      return false;
    }

    // 先試著 flush 一次（有些可能一開始就已經有 script 了）
    const finishedInitially = await tryFlushReady();
    if (finishedInitially) {
      return;
    }

    // 6) 每 3 秒重查 DB：只查還沒 ready、而且 index 之後的那幾筆
    timer = setInterval(async () => {
      if (ended || res.writableEnded) {
        clearInterval(timer);
        return;
      }

      // 還沒送出的 & 不完整的 idList
      const needIds = scriptMap
        .slice(currentIndex)
        .filter(
          it =>
            !it.reporter ||
            !it.reporter.toString().trim() ||
            !Array.isArray(it.chat) ||
            !it.chat.length
        )
        .map(it => it.id);

      if (!needIds.length) {
        // 可能只是前面還沒 flush 完，試一次
        const done = await tryFlushReady();
        if (done) return;
        return;
      }

      // 再從 DB 補一次資料
      try {
        await loadReporterAndChatForIds(needIds, scriptById);
      } catch (err) {
        console.error('loadReporterAndChatForIds in timer error:', err);
        // 這裡先不直接結束，下一輪再試
      }

      // 補完後再試著 flush
      const done = await tryFlushReady();
      if (done) return;
    }, 3000);

    // 如果前端關掉連線（例如按「中止」），就停止 timer
    req.on('close', () => {
      if (!ended) {
        console.log('client closed getScript connection');
        if (timer) clearInterval(timer);
        ended = true;
      }
    });
  } catch (err) {
    console.error('getScript fatal error:', err);
    if (!res.headersSent) {
      return next(err);
    }
    // headers 已送出就只能結束連線
    try {
      res.end();
    } catch (_) {}
  }
}

// 從 DB 拿一筆腳本（你自己調 schema）
/*async function getScriptRowFromDb(newsId) {
  const sql = `
    SELECT news_id, reporter_script, chat_script
    FROM news_data
    WHERE news_id = ?
  `;
  const [rows] = await pool.query(sql, [newsId]);
  return rows[0] || null;
}

// SSE：一個一個送腳本
async function getScript(req, res, next) {
  let query
  let clientClosed = false;

  // 前端關掉連線就不要再寫資料了
  req.on('close', () => {
    clientClosed = true;
  });

  // 設定 SSE header
  res.setHeader('Content-Type', 'text/event-stream; charset=utf-8');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders && res.flushHeaders();

  // 小工具：送一筆 event 給前端
  function sendEvent(data) {
    if (clientClosed) return;
    // SSE 格式：data: ...\n\n
    res.write(`data: ${JSON.stringify(data)}\n\n`);
  }

  try {
    // 1. 先拿到 idList（你可以改成從 body/param 拿）
    const idList = await searchNews(req, res, next); // 假設回傳 Array<number>
    // 如果你的 searchNews 直接回 res，就改成別的 helper，重點是拿到 idList

    // 2. 逐一處理每個 newsId
    for (const newsId of idList) {
      if (clientClosed) break;

      // 2-1 先查 DB 有沒有腳本
      let row = await getScriptRowFromDb(newsId);

      // 2-2 如果沒有，就呼叫外部函式幫你產生腳本 + 寫回 DB
      if (!row) {
        try {
          await runAllWorker(newsId); // 你自己實作：去叫 LLM / 更新 DB
          row = await getScriptRowFromDb(newsId);
        } catch (err) {
          // 產生失敗也可以先丟一個錯誤事件給前端
          sendEvent({ type: 'item-error', newsId, error: err.message || 'buildScript failed' });
          continue; // 換下一筆
        }
      }

      if (!row) {
        // 真的還是沒拿到資料
        sendEvent({ type: 'item-missing', newsId });
      } else {
        // 2-3 有資料就送一筆
        // 這邊你想送什麼欄位就自己挑
        sendEvent({
          type: 'item',
          newsId: row.news_id,
          reporterScript: row.reporter_script,
          chatScript: row.chat_script
        });
      }
    }

    // 3. 全部結束，通知前端 done
    sendEvent({ type: 'done' });
    res.end();
  } catch (err) {
    // 出錯時可以丟一個 error 事件，然後交給 next
    if (!clientClosed) {
      sendEvent({ type: 'error', message: err.message || 'unknown error' });
      res.end();
    }
    next(err);
  }
}*/

/*async function getReporterChatText(idList) {
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
}*/


/*async function getIdList() {
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
}*/

// 取得 一般朗讀 + 新聞播報 + 聊天對白 腳本
/*async function getScript(req, res, next) {

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
}*/

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
// ========== 快速播放功能 ==========
// 引入 TTS 控制器的內部函數
const { textToSpeechAndSaveInternal } = require('./ttsController');

/**
 * 快速播放腳本生成 API
 * 從資料庫獲取熱門新聞 → 生成播報稿 → 轉換為 MP3
 */
async function quickScript(req, res, next) {
    let { limit } = req.query ?? {};

    try {
      [ limit ] = await checkRequireField ([
        { field: 'limit'  , data: limit   , type: 'number'  , other: ['non_null'] , default: 10}
      ]);
    } catch (err) {
      err.desc = "middlewares-quickScript(): Missing or Invalid required fields";
      return next(err);
    }

    // 1️⃣ 從 searchNews 按熱度排序抓前 N 筆
    let fakeReq = {
      query: { mode: "complex", order: "heat", limit: limit },
      body: {}
    };

    let newsResult;
    try {
      newsResult = await callAndCatchApiSuccess(searchNews, fakeReq);
    } catch (err) {
      err.desc = "middlewares-quickScript(): call searchNews error";
      return next(err);
    }

    // 2️⃣ 提取新聞內容
    const items = newsResult.complexList || [];

    if (items.length === 0) {
      return res.apiSuccess({ scripts: [] }, "No news found");
    }

    // 3️⃣ 對每一筆新聞呼叫本地 Ollama 生成 quick-script
    let quickScripts;
    try {
      quickScripts = await Promise.all(
        items.map((item) => {
          const bodyText = (item.newsBody || [])
            .filter(part => typeof part.text === 'string' && part.text.trim() !== '')
            .map(part => part.text.trim())
            .join('\n');

          return callOllamaQuickScript({
            id: item.newsId,
            title: item.newsTitle,
            text: shortenArticle(bodyText)
          });
        })
      );
    } catch (err) {
      err.desc = 'middlewares-quickScript(): call ollama quick-script error';
      return next(err);
    }

    // 4️⃣ 將生成的播報稿轉換為 MP3 並儲存
    console.log(`[QuickScript] 開始批次 TTS 轉換 ${quickScripts.length} 個播報稿`);

    let audioFiles;
    try {
      audioFiles = await Promise.all(
        quickScripts.map((script) =>
          textToSpeechAndSaveInternal(script.id, script.text)
        )
      );
    } catch (err) {
      console.error('[QuickScript] TTS 轉換錯誤:', err);
      err.desc = 'middlewares-quickScript(): TTS conversion error';
      return next(err);
    }

    // 5️⃣ 組合返回結果
    const results = quickScripts.map((script, index) => ({
      id: script.id,
      title: script.title,
      text: script.text,
      audioFile: audioFiles[index].filename,
      audioPath: audioFiles[index].filepath,
      audioSize: audioFiles[index].fileSize
    }));

    console.log(`[QuickScript] 完成: 生成 ${results.length} 個播報稿及音訊檔案`);

    return res.apiSuccess({ scripts: results }, "Quick Script Generated with Audio");
}

/**
 * 呼叫本地 Ollama 的 quick-script model
 */
async function callOllamaQuickScript({ id, title, text }) {
  const prompt =
    '標題：' + title + '\n' +
    '內容：' + text + '\n\n' +
    '請依照 quick-script 的規則產生簡短的新聞播報稿。';

  const start = Date.now();
  const payload = {
    model: QUICK_SCRIPT_MODEL,
    prompt,
    stream: false,
    options: {
      num_predict: 150
    },
  };

  let resp;
  try {
    resp = await axios.post(OLLAMA_URL, payload, {
      headers: { 'Content-Type': 'application/json' },
      timeout: 10000, // 10秒超時
    });
  } catch (err) {
    if (err.code === 'ECONNABORTED') {
      console.error(`Ollama timeout: quickScript id=${id}`);
    } else {
      console.error(`Ollama error: quickScript id=${id}`, err.message);
    }
    throw err;
  }

  let script = resp.data?.response || '';
  script = cleanNewsScript(script);

  console.log(`quick-script latency(ms) for id ${id}:`, Date.now() - start);

  return {
    id,
    title,
    text: script,
  };
}




/*async function callDeepseekReporterScript({ id, title, text }) {

  // 組 prompt：請 DeepSeek 幫忙改寫成 80~100 字的播報稿
  const prompt =
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
  const prompt =
    '將下列新聞改寫成約 60 到 80 字的中文電視新聞播報稿。' +
    '口語化、第三人稱，只保留關鍵事實與數字，不新增資訊或評論，' +
    '不要加標題或說明文字，也不要提到自己或 AI 身分。\n\n' +
    '【標題】\n' + title + '\n\n' +
    '【內文】\n' + text + '\n\n' +
    '請直接輸出播報稿內容。';

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
}*/

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
  quickScript,  // 新增：快速播放功能
  callAskScript
};