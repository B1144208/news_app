// api/threadsWorker/newsLocationWorker.js
'use strict';

const pool = require('../connect_db');
const { newsLocationClassifier } = require('../middlewares/classifierController');
const { searchLocation } = require('../middlewares/locationController');
const { getText } = require('../middlewares/scriptController');
const { callAndCatchApiSuccessInGeneralFunction } = require('../utils/fakeHelper');

const SLEEP_WHEN_EMPTY_MS = 60 * 60 * 1000;
const SHORT_SLEEP_MS = 5 * 1000;

function sleep (ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * 從 news_task 抓出「還沒做 location（news_location = 0）」的 news_id
 * 依照五個欄位的加總分數由大到小排序，再依照 created_at 越新越前面
 * 一次最多抓 10 筆
 */
async function fetchPendingNewsIds () {
  const sql = `
    SELECT
      nt.news_id,
      (
        nt.news_group +
        nt.news_location +
        nt.news_keyword
      ) AS score
    FROM news_task AS nt
    JOIN news_data AS nd
      ON nd.news_id = nt.news_id
    WHERE nt.news_location = 0
    ORDER BY
      score DESC,
      nd.created_at
    LIMIT 10;
  `;

  const [rows] = await pool.query(sql);
  return rows.map(r => r.news_id);
}

/**
 * 把 classifier 回傳的 location 結果寫入 news_location 資料表
 */
async function insertNewsLocationsForOneNews (newsId, result) {
    // === 0. 先準備要查的名稱陣列，若原本就是 []，就當作 ['其他'] ===
    let namesToSearch;
    if (Array.isArray(result) && result.length > 0) {
        namesToSearch = result;
    } else {
        namesToSearch = ['其他'];
    }

    const insertSql = `
        INSERT IGNORE INTO news_location (news_id, location_data_id, location_detail_id)
        VALUES ?
    `;

    const rowsToInsert = []; // [[newsId, dataId, detailId], ...]

    // === 1. 逐一呼叫 searchLocation，把結果整理成 {type,id} → rowsToInsert ===
    for (const rawName of namesToSearch) {
        const locationName = rawName || '其他';

        let searchLocationResult;
        try {
        const fakeReq = { query: { name: locationName } };
        searchLocationResult = await callAndCatchApiSuccessInGeneralFunction(
            searchLocation,
            fakeReq
        );
        } catch (err) {
        // 搜尋失敗就跳過
        continue;
        }

        if (!searchLocationResult || !searchLocationResult.type || !searchLocationResult.id) {
        continue;
        }

        const { type, id } = searchLocationResult;
        let dataId = null;
        let detailId = null;

        if (type === 'data') {
            dataId = id;
        } else if (type === 'detail') {
            detailId = id;
        } else {
            continue;
        }

        rowsToInsert.push([newsId, dataId, detailId]);
    }

    // === 2. 若全部 search 完還是沒有任何可用的結果，再保底塞「其他」一次 ===
    if (rowsToInsert.length === 0) {
        try {
        const fakeReq = { query: { name: '其他' } };
        const fallback = await callAndCatchApiSuccessInGeneralFunction(
            searchLocation,
            fakeReq
        );

        if (fallback && fallback.type && fallback.id) {
            let dataId = null;
            let detailId = null;

            if (fallback.type === 'data') {
                dataId = fallback.id;
            } else if (fallback.type === 'detail') {
                detailId = fallback.id;
            }

            if (dataId !== null || detailId !== null) {
                rowsToInsert.push([newsId, dataId, detailId]);
            }
        }
        } catch (err) {
        console.warn('[newsLocationWorker] fallback「其他」搜尋也失敗，news_id =', newsId, 'err =', err.message);
        }
    }

    // === 3. 真的完全沒有任何 row 可以寫入就結束 ===
    if (rowsToInsert.length === 0) {
        return;
    }

    // === 4. 一次批次 INSERT IGNORE ===
    try {
        await pool.query(insertSql, [rowsToInsert]);
    } catch (err) {
        console.warn('[newsLocationWorker] 批次寫入 news_location 失敗，news_id =', newsId, 'err =', err.message);
    }
}

/**
 * 將單一 news 的 news_task.news_location 設為 1 （表示已完成）
 */
async function markTaskDone (newsId) {
  const sql = `
    UPDATE news_task
    SET news_location = 1
    WHERE news_id = ?;
  `;
  await pool.query(sql, [newsId]);
}

/**
 * 處理單一 news_id 的完整流程：
 * 1. 呼叫 classifier 拿到 location 結果
 * 2. 寫入 news_location
 * 3. 將 news_task.news_location 設為 1
 */
async function handleOneNews (newsItem) {
  const newsId = newsItem.id;
  const title  = newsItem.title || '';
  const body   = newsItem.text  || '';

  console.log("=========== newsId : ", newsId, " ===========\n");

  const newsText = `${title}\n${body}`.trim();

  const fakeReq = {
    body: { newsText }
  };

  try {
    const result = await callAndCatchApiSuccessInGeneralFunction(
      newsLocationClassifier,
      fakeReq
    );

    console.log("result: ", result);

    await insertNewsLocationsForOneNews(newsId, result.data);
    await markTaskDone(newsId);
  } catch (err) {
    err.desc = 'threadsWorker-newsLocation-handleOneNews(): ' + (err.message || '');
    console.error(err.desc);
  }
}

/**
 * 主迴圈：
 * - 一直從 DB 抓待處理的 idList
 * - 若有資料，逐筆處理
 * - 若沒有資料，sleep 一小時後再試
 */
async function mainLoop () {
  console.log('[newsLocationWorker] 啟動');

  while (true) {
    try {
      const idList = await fetchPendingNewsIds();

      if (idList.length === 0) {
        console.log('[newsLocationWorker] 目前沒有待處理的 news_location 任務，一小時後再檢查');
        await sleep(SLEEP_WHEN_EMPTY_MS);
        continue;
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
          console.warn('[newsLocationWorker] getText 回傳不是陣列，實際：', newsTextList);
          newsTextList = [];
        }
      } catch (err) {
        console.error('[newsLocationWorker] 呼叫 getText 發生錯誤：', err);
        await sleep(30 * 1000);
        continue;
      }

      // 3) 對這批文字逐筆做 location 分類
      for (const newsItem of newsTextList) {
        if (!newsItem || typeof newsItem.id === 'undefined') {
          console.warn('[newsLocationWorker] newsItem 格式不正確，略過：', newsItem);
          continue;
        }

        try {
          await handleOneNews(newsItem);
        } catch (err) {
          console.error('[newsLocationWorker] 處理 news_id =', newsItem.id, '時發生錯誤：', err);
        }
      }

      // 一輪跑完後 while 會自動再抓下一輪
    } catch (err) {
      console.error('[newsLocationWorker] 主迴圈發生錯誤：', err);
      await sleep(30 * 1000);
    }
  }
}

// 直接啟動主程式
mainLoop().catch(err => {
  console.error('[newsLocationWorker] 無法啟動：', err);
  process.exit(1);
});

// 優雅關閉
process.on('SIGINT', () => {
  console.log('\n[newsLocationWorker] 收到 SIGINT，準備結束');
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log('\n[newsLocationWorker] 收到 SIGTERM，準備結束');
  process.exit(0);
});
