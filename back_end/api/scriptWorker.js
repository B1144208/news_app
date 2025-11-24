/**
 * scriptWorker.js
 * 
 * 角色：背景 Worker，給 PM2 執行
 * 任務：
 *  1. 從 script_task 取得 news_id，放入 scriptQueue（RAM）
 *  2. 每次從 scriptQueue 拿 10 筆 id → 丟給 generalScript 取得 [{id,title,text}]
 *  3. 用 Promise.all：
 *      - reporterScript：deepseek-r1:1.5b「記者播報模式」
 *      - chatScript：聊天對白模式（目前先留白）
 *  4. 等 10 筆的 reporterText + chatText 都拿到後，
 *     用 CASE WHEN 的 SQL 一次更新 news_data.reporte r_script / chat_script
 *  5. 刪除已處理完的 script_task
 */

const path = require('path');
const axios = require('axios');
const pool = require('./connect_db'); // ⬅️ 請依你的檔案位置調整
const { generalScript } = require('./middlewares/scriptController'); // 已存在的函式

// === Ollama / 模型設定 ===
const OLLAMA_URL = 'http://localhost:11434/api/generate';
const REPORTER_MODEL = 'deepseek-r1:1.5b';

// === Worker 參數 ===
const BATCH_SIZE = 10;     // 每次處理 10 筆
const SLEEP_MS_WHEN_EMPTY = 5000;

// scriptQueue：放在 RAM 的待處理 news_id
let scriptQueue = [];

/* -----------------------------------------------------------
 * 小工具：sleep
 * ---------------------------------------------------------*/
function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/* -----------------------------------------------------------
 * cleanNewsScript：把 AI 免責聲明 / 自我介紹清掉（沿用你之前的邏輯）
 * ---------------------------------------------------------*/
function cleanNewsScript(raw) {
  if (!raw) return '';

  const lines = raw
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter(Boolean);

  const filtered = lines.filter((line) => {
    return !(
      /作為.?AI/i.test(line) ||
      /作為一個?人工智慧/i.test(line) ||
      /身為.?AI/i.test(line) ||
      /我是一個?AI/i.test(line) ||
      /無法提供(醫療|法律)建議/.test(line) ||
      /不能替代專業(醫療|法律)/.test(line) ||
      /如果您有任何問題/.test(line) ||
      /如果你有任何問題/.test(line) ||
      /建議您尋求專業/.test(line) ||
      /僅供參考/.test(line) ||
      /感謝你的提問/.test(line) ||
      /感謝您的提問/.test(line) ||
      /回答你的問題是/.test(line) ||
      /回答您的問題是/.test(line) ||
      /超出我的能力範圍/.test(line)
    );
  });

  let cleaned = filtered.join('\n').trim();
  cleaned = cleaned.replace(/^(播報稿|新聞播報|以下是播報內容)[：:\s]*/i, '');
  return cleaned;
}

/* -----------------------------------------------------------
 * getScriptId：從 script_task JOIN news_data 取得待處理的 id
 *  - 重啟或 scriptQueue 為空時會呼叫這個 function
 *  - 依照「最新時間優先」排序
 * ---------------------------------------------------------*/
async function getScriptId(limit = 100) {
  const sql = `
    SELECT st.news_id
    FROM script_task AS st
    JOIN news_data AS nd ON nd.news_id = st.news_id
    -- TODO: 如果你只想處理尚未產生 script 的，這裡可以加條件：
    -- WHERE (nd.reporter_script IS NULL OR nd.chat_script IS NULL)
    ORDER BY nd.created_at DESC
    LIMIT ?
  `;

  const [rows] = await pool.query(sql, [limit]);
  // 回傳純 id 陣列
  return rows.map((r) => r.news_id);
}

/* -----------------------------------------------------------
 * fetchNewsBatchByIds：
 *   透過 generalScript 取得 [{id,title,text}] 陣列
 *   - 這裡同時相容兩種 generalScript 寫法：
 *     1) generalScript(idList) 直接回傳陣列
 *     2) Express middleware: generalScript(req,res,next)
 * ---------------------------------------------------------*/
async function fetchNewsBatchByIds(idList) {
  if (!idList || idList.length === 0) return [];

  // generalScript.length === 1 → 假設是 generalScript(idList)
  if (generalScript.length === 1) {
    return await generalScript(idList);
  }

  // 否則當作 Express middleware 來呼叫
  // 需要你自己在 generalScript 裡，看到 body.id 時回傳 [{id,title,text}]
  return new Promise((resolve, reject) => {
    const fakeReq = {
      body: { id: idList },
      params: {},
      query: {},
    };

    // fakeRes 只實作 apiSuccess / apiError 兩個用得到的
    const fakeRes = {
      apiSuccess(data) {
        resolve(data);
      },
      apiError(err) {
        reject(err);
      },
    };

    const next = (err) => {
      if (err) reject(err);
    };

    try {
      const maybePromise = generalScript(fakeReq, fakeRes, next);
      // 如果 generalScript 本身回傳 Promise
      if (maybePromise && typeof maybePromise.then === 'function') {
        maybePromise.catch(reject);
      }
    } catch (err) {
      reject(err);
    }
  });
}

/* -----------------------------------------------------------
 * reporterScript：用 deepseek-r1:1.5b 產生「記者播報模式」
 *  輸入：{id, title, text}
 *  輸出：string (reporterText)
 * ---------------------------------------------------------*/
async function reporterScript({ id, title, text }) {
  const system =
    '你是一位台灣電視新聞台的專業播報記者，只負責把輸入的新聞改寫成播報稿。\n' +
    '規則：\n' +
    '1. 每次輸出一段約 80~120 個字的中文播報稿。\n' +
    '2. 用口語化、第三人稱的電視新聞播報語氣。\n' +
    '3. 只保留關鍵事實與數字，不新增任何資訊或評論。\n' +
    '4. 不得出現「我是AI」「身為AI」「如果您有任何問題」等類似字句。\n' +
    '5. 不得加上標題、說明文字或「播報稿：」「新聞內容：」等提示語。\n' +
    '6. 輸出內容中嚴禁出現「【」或「】」這兩個符號。\n' +
    '若違反以上任一條規則，視為錯誤回答。';

  const prompt =
    '【標題】\n' + (title || '') + '\n\n' +
    '【內文】\n' + (text || '') + '\n\n' +
    '請依規則產生播報稿。';

  const payload = {
    model: REPORTER_MODEL,
    system,
    prompt,
    stream: false,
    options: {
      // 依需求調整，讓模型大約說 80~120 字
      num_predict: 200,
    },
  };

  const start = Date.now();
  try {
    const resp = await axios.post(OLLAMA_URL, payload, {
      headers: { 'Content-Type': 'application/json' },
    });

    let script = resp.data?.response || '';
    // 移除 <think>…</think>
    script = script.replace(/<think>[\s\S]*?<\/think>/g, '').trim();
    script = cleanNewsScript(script);

    console.log(`[reporterScript] id=${id}, latency(ms)=`, Date.now() - start);
    return script;
  } catch (err) {
    console.error(`[reporterScript] error on id=${id}:`, err.message);
    // 失敗時回傳空字串（或你可以選擇 throw，讓外層處理）
    return '';
  }
}

/* -----------------------------------------------------------
 * chatScript：聊天對白模式（目前留白 stub）
 * 之後你可以改成用另一個模型 / system prompt。
 * 這裡先保留介面，回傳空字串，讓整個 worker 架構先跑得起來。
 * ---------------------------------------------------------*/
async function chatScript({ id, title, text }) {
  // TODO: 在這裡實作聊天對白模式的 LLM 呼叫邏輯
  // 目前先回傳空字串，避免影響整體流程
  return '';
}

/* -----------------------------------------------------------
 * bulkUpdateNewsData：
 *   使用 CASE WHEN 一次更新多筆 news_data 的
 *   reporter_script / chat_script
 *
 *  results: [{ id, reporterText, chatText }, ...]
 * ---------------------------------------------------------*/
async function bulkUpdateNewsData(results) {
  if (!results || results.length === 0) return;

  const ids = results.map((r) => r.id);

  // 動態組 CASE WHEN
  const reporterCases = results
    .map(() => 'WHEN ? THEN ?')
    .join('\n        ');

  const chatCases = results
    .map(() => 'WHEN ? THEN ?')
    .join('\n        ');

  const wherePlaceholders = ids.map(() => '?').join(', ');

  const sql = `
    UPDATE news_data
    SET
      reporter_script = CASE news_id
        ${reporterCases}
        ELSE reporter_script
      END,
      chat_script = CASE news_id
        ${chatCases}
        ELSE chat_script
      END
    WHERE news_id IN (${wherePlaceholders});
  `;

  const params = [];

  // reporter_script 的 CASE：id, reporterText
  results.forEach((r) => {
    params.push(r.id, r.reporterText);
  });

  // chat_script 的 CASE：id, chatText
  results.forEach((r) => {
    params.push(r.id, r.chatText);
  });

  // WHERE IN (...) 的 ids
  params.push(...ids);

  await pool.query(sql, params);
}

/* -----------------------------------------------------------
 * removeScriptTasks：
 *   處理完的 news_id 從 script_task 刪掉，避免重複處理
 * ---------------------------------------------------------*/
async function removeScriptTasks(ids) {
  if (!ids || ids.length === 0) return;

  const placeholders = ids.map(() => '?').join(', ');
  const sql = `DELETE FROM script_task WHERE news_id IN (${placeholders})`;

  await pool.query(sql, ids);
}

/* -----------------------------------------------------------
 * refillQueueIfNeeded：
 *   scriptQueue 為空時，從資料庫重新撈 id 塞進 queue
 * ---------------------------------------------------------*/
async function refillQueueIfNeeded() {
  if (scriptQueue.length > 0) return;

  console.log('[Worker] scriptQueue is empty, fetching from script_task…');
  const ids = await getScriptId(200); // 一次先抓 200 筆 id 放進 queue

  if (ids.length === 0) {
    console.log('[Worker] no script_task found. sleep…');
    await sleep(SLEEP_MS_WHEN_EMPTY);
    return;
  }

  scriptQueue.push(...ids);
  console.log('[Worker] loaded ids into scriptQueue:', scriptQueue.length);
}

/* -----------------------------------------------------------
 * mainLoop：
 *   1. 如果 queue 空 → refill
 *   2. 從 queue 拿 10 筆 id → generalScript → 得到 [{id,title,text}]
 *   3. Promise.all 跑 reporterScript + chatScript
 *   4. 全部完成後 bulkUpdateNewsData
 *   5. 從 script_task 刪除已處理的 id
 * ---------------------------------------------------------*/
async function mainLoop() {
  console.log('[Worker] scriptWorker started.');

  while (true) {
    try {
      await refillQueueIfNeeded();

      if (scriptQueue.length === 0) {
        // refillQueueIfNeeded 裡已經 sleep 過了，這邊直接下一圈
        continue;
      }

      const batchIds = scriptQueue.splice(0, BATCH_SIZE);
      console.log('[Worker] processing ids:', batchIds);

      // 1️⃣ 取得 [{id,title,text}]
      const items = await fetchNewsBatchByIds(batchIds);

      if (!items || items.length === 0) {
        console.warn('[Worker] fetchNewsBatchByIds returned empty, ids:', batchIds);
        continue;
      }

      // 建一個 map 以防回傳順序跟 batchIds 不一致
      const itemMap = new Map();
      items.forEach((it) => itemMap.set(it.id, it));

      const tasks = batchIds
        .map((id) => itemMap.get(id))
        .filter(Boolean); // 避免某些 id 找不到

      if (tasks.length === 0) {
        console.warn('[Worker] no valid tasks after mapping, ids:', batchIds);
        continue;
      }

      // 2️⃣ 對每一筆同時跑 reporterScript + chatScript
      const results = await Promise.all(
        tasks.map(async (item) => {
          const [reporterText, chatText] = await Promise.all([
            reporterScript(item),
            chatScript(item), // 目前是 stub，之後你可以改成真正聊天模式
          ]);

          return {
            id: item.id,
            reporterText,
            chatText,
          };
        }),
      );

      // 3️⃣ 批次更新 news_data
      await bulkUpdateNewsData(results);

      // 4️⃣ 刪除 script_task 中已處理的 id
      const doneIds = results.map((r) => r.id);
      await removeScriptTasks(doneIds);

      console.log(
        '[Worker] batch done. updated & removed ids:',
        doneIds,
      );
    } catch (err) {
      console.error('[Worker] mainLoop error:', err);
      // 避免爆掉 CPU，發生錯誤時小睡一下再繼續
      await sleep(2000);
    }
  }
}

/* -----------------------------------------------------------
 * 啟動 worker
 * ---------------------------------------------------------*/
mainLoop().catch((err) => {
  console.error('[Worker] fatal error, exiting:', err);
  process.exit(1);
});
