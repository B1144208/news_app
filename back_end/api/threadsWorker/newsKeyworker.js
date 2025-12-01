// api/threadsWorker/newsKeywordWorker.js
'use strict';

const pool = require('../connect_db');
const { newsKeywordClassifier } = require('../middlewares/classifierController');
const { getText } = require('../middlewares/scriptController');
const { callAndCatchApiSuccessInGeneralFunction } = require('../utils/fakeHelper');

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * 從 news_task 抓出「還沒做 keyword（news_keyword = 0）」的 news_id
 * 依照五個欄位的加總分數由大到小排序，再依照 created_at 越新越前面
 * 一次最多抓 100 筆
 */
async function fetchPendingNewsIds() {
  const sql = `
    SELECT
      nt.news_id,
      (
        nt.news_group +
        nt.news_location +
        nt.news_keyword +
      ) AS score
    FROM news_task AS nt
    JOIN news_data AS nd
      ON nd.news_id = nt.news_id
    WHERE nt.news_keyword = 0
    ORDER BY
      score DESC,
      nd.created_at DESC
    LIMIT 100;
  `;

  const [rows] = await pool.query(sql);
  return rows.map(r => r.news_id);
}

/**
 * 把 classifier 回傳的 keywords 寫入資料表
 * 這裡假設有一張：news_keyword(news_id, keyword_text)
 * 若你的實際表結構不同，只要改 SQL 與 rowsToInsert 組法即可。
 */
async function insertNewsKeywordsForOneNews(newsId, keywords) {
  // 1. 把結果整理成要寫入的陣列
  let namesToInsert;

  if (Array.isArray(keywords) && keywords.length > 0) {
    namesToInsert = keywords
      .filter(k => typeof k === 'string')
      .map(k => k.trim())
      .filter(Boolean); // 去掉空字串
  } else {
    // 完全沒有 keyword，就不寫任何東西，交由上層判斷是否要 markTaskDone
    return false;
  }

  if (namesToInsert.length === 0) {
    return false;
  }

  // 去重
  namesToInsert = [...new Set(namesToInsert)];

  const insertSql = `
    INSERT IGNORE INTO news_keyword (news_id, keyword_text)
    VALUES ?
  `;

  const rowsToInsert = namesToInsert.map(name => [newsId, name]);

  try {
    await pool.query(insertSql, [rowsToInsert]);
    return true;
  } catch (err) {
    console.warn(
      '[newsKeywordWorker] 批次寫入 news_keyword 失敗，news_id =',
      newsId,
      'err =',
      err.message
    );
    return false;
  }
}

/**
 * 將單一 news 的 news_task.news_keyword 設為 1 （表示已完成）
 */
async function markTaskDone(newsId) {
  const sql = `
    UPDATE news_task
    SET news_keyword = 1
    WHERE news_id = ?;
  `;
  await pool.query(sql, [newsId]);
}

/**
 * 處理單一 news 的完整流程：
 * 1. 呼叫 keyword classifier 拿到 keywords 結果 (string[])
 * 2. 寫入 news_keyword 關聯表
 * 3. 將 news_task.news_keyword 設為 1
 */
async function handleOneNews(newsItem) {
  const newsId = newsItem.id;
  const title = newsItem.title || '';
  const body = newsItem.text || '';

  // 組成送進模型的文字：標題 + 內文
  const newsText = `${title}\n${body}`.trim();

  const fakeReq = {
    body: { newsText }
  };

  try {
    // 1) 呼叫 keyword 模型
    const result = await callAndCatchApiSuccessInGeneralFunction(
      newsKeywordClassifier,
      fakeReq
    );
    console.log('[newsKeywordWorker] classifier result:', result);

    // 檢查 classifier 是否正常
    if (!result || result.success === false || !result.data) {
      console.warn(
        `[newsKeywordWorker] news_id=${newsId} newsKeywordClassifier 未正常完成，略過 markTaskDone`
      );
      return;
    }

    const keywords = result.data; // 預期為 string[]

    // 2) 寫入 DB
    const ok = await insertNewsKeywordsForOneNews(newsId, keywords);
    console.log(
      `[newsKeywordWorker] insertNewsKeywordsForOneNews result for news_id=${newsId}:`,
      ok
    );

    if (!ok) {
      console.warn(
        `[newsKeywordWorker] news_id=${newsId} insertNewsKeywordsForOneNews 失敗或沒有任何 keyword，略過 markTaskDone`
      );
      return;
    }

    // 3) 只有在前兩步都正常才標記完成
    await markTaskDone(newsId);
  } catch (err) {
    err.desc =
      'threadsWorker-newsKeyword-handleOneNews(): ' + (err.message || '');
    console.error(err.desc);
  }
}

/**
 * 主流程：
 * - 從 DB 抓待處理的 idList
 * - 呼叫 getText 取得 {id,title,text}
 * - 逐筆做 keyword 分類
 */
async function runNewsKeywordWorker() {
  console.log('[newsKeywordWorker] 啟動');

  try {
    // 1) 抓待處理的 news_id 清單
    const idList = await fetchPendingNewsIds();

    if (idList.length === 0) {
      console.log('[newsKeywordWorker] 目前沒有待處理的 news_keyword 任務');
      return;
    }

    // 2) 呼叫 getText，把這批 id 換成 {id, title, text} 陣列
    let newsTextList;
    try {
      const fakeReqForGetText = {
        query: { idList }
      };

      newsTextList = await callAndCatchApiSuccessInGeneralFunction(
        getText,
        fakeReqForGetText
      );

      if (!Array.isArray(newsTextList)) {
        console.warn(
          '[newsKeywordWorker] getText 回傳不是陣列，實際：',
          newsTextList
        );
        newsTextList = [];
      }
    } catch (err) {
      console.error('[newsKeywordWorker] 呼叫 getText 發生錯誤：', err);
      await sleep(30 * 1000);
      return;
    }

    // 3) 逐筆處理
    for (const newsItem of newsTextList) {
      if (!newsItem || typeof newsItem.id === 'undefined') {
        console.warn(
          '[newsKeywordWorker] newsItem 格式不正確，略過：',
          newsItem
        );
        continue;
      }

      try {
        await handleOneNews(newsItem);
      } catch (err) {
        console.error(
          '[newsKeywordWorker] 處理 news_id =',
          newsItem.id,
          '時發生錯誤：',
          err
        );
      }
    }
  } catch (err) {
    console.error('[newsKeywordWorker] 主流程發生錯誤：', err);
    await sleep(30 * 1000);
  }
}

// 啟動 worker
runNewsKeywordWorker().catch(err => {
  console.error('[newsKeywordWorker] 無法啟動：', err);
  process.exit(1);
});

// 優雅關閉
process.on('SIGINT', () => {
  console.log('\n[newsKeywordWorker] 收到 SIGINT，準備結束');
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log('\n[newsKeywordWorker] 收到 SIGTERM，準備結束');
  process.exit(0);
});
