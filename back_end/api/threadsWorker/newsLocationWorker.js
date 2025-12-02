// api/threadsWorker/newsLocationWorker.js
'use strict';

const pool = require('../connect_db');
const { newsLocationClassifier } = require('../middlewares/classifierController');
const { searchLocation } = require('../middlewares/locationController');
const { getText } = require('../middlewares/scriptController');
const { callAndCatchApiSuccessInGeneralFunction } = require('../utils/fakeHelper');

function sleep (ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * 從 news_task 抓出「還沒做 location（news_location = 0）」的 news_id
 * 依照五個欄位的加總分數由大到小排序，再依照 created_at 越舊越前面
 * 一次最多抓 100 筆
 */
async function fetchPendingNewsIds(LIMIT) {
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
    LIMIT ${LIMIT};
  `;

  const [rows] = await pool.query(sql);
  return rows.map(r => r.news_id);
}

/**
 * 把 classifier 回傳的 location 結果寫入 news_location 資料表
 */
async function insertNewsLocationsForOneNews (newsId, result) {
    // === 0. 正規化 result：只接受 string[]，其他都當成 [] ===
    let names = [];

    if (Array.isArray(result)) {
        names = result
            .filter(v => typeof v === 'string')
            .map(v => v.trim())
            .filter(Boolean);
    }

    // 去重
    names = [...new Set(names)];

    // 若最後沒有任何有效地點名稱，就直接結束，不寫入任何東西
    if (names.length === 0) {
        return true;
    }

    const insertSql = `
        INSERT IGNORE INTO news_location (
            news_id,
            location_region_id,
            location_country_id,
            location_state_id
        )
        VALUES ?
    `;

    const rowsToInsert = []; // [[newsId, regionId, countryId, stateId], ...]

    // === 1. 逐一呼叫 searchLocation，把結果整理成 rowsToInsert ===
    for (const locationName of names) {
        let searchLocationResult;
        try {
            const fakeReq = { query: { name: locationName } };
            searchLocationResult = await callAndCatchApiSuccessInGeneralFunction(
                searchLocation,
                fakeReq
            );
        } catch (err) {
            console.warn('[newsLocationWorker] searchLocation 失敗，news_id =', newsId, 'name =', locationName, 'err =', err.message);
            continue;
        }

        if (!searchLocationResult || !searchLocationResult.type || !searchLocationResult.id) {
            continue;
        }

        const { type, id } = searchLocationResult;
        let regionId  = null;
        let countryId = null;
        let stateId   = null;

        if (type === 'region') {
            regionId = id;
        } else if (type === 'country') {
            countryId = id;
        } else if (type === 'state') {
            stateId = id;
        } else {
            continue;
        }

        rowsToInsert.push([newsId, regionId, countryId, stateId]);
    }

    // === 2. 如果搜尋完沒有任何可以寫入的資料，就結束 ===
    if (rowsToInsert.length === 0) {
        return true;
    }

    // === 3. 一次批次 INSERT IGNORE ===
    try {
        await pool.query(insertSql, [rowsToInsert]);
        return true;
    } catch (err) {
        console.warn('[newsLocationWorker] 批次寫入 news_location 失敗，news_id =', newsId, 'err =', err.message);
        return false;
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
  const newsText = `${title}\n${body}`.trim();

  const fakeReq = {
    body: { newsText }
  };

  try {
    const result = await callAndCatchApiSuccessInGeneralFunction(newsLocationClassifier, fakeReq);
    console.log("1. result", result);
    if (!result || result.success === false || !result.data) {
        console.warn( `[newsLocationWorker] news_id=${newsId} newsLocationClassifier 未正常完成，略過 markTaskDone`);
        return; // 直接跳過這筆，讓外層去跑下一個 newsId
    }

    const insertResult = await insertNewsLocationsForOneNews(newsId, result.data);
    console.log("2. insertResult", insertResult);
    if (insertResult === false) {
        console.warn(`[newsLocationWorker] news_id=${newsId} insertNewsLocationForOneNews 回傳失敗，略過 markTaskDone`);
        return;
    }

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
async function runLocationWorker(LIMIT) {
  console.log('[newsLocationWorker] 啟動');

    try {
        const idList = await fetchPendingNewsIds(LIMIT);

        console.log("抓取" , idList, " 資料")

        if (idList.length === 0) {
            console.log('[newsLocationWorker] 目前沒有待處理的 news_location 任務');
            return;
        }

        // 1) 呼叫 getText，把這批 id 換成 {id, title, text} 陣列
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
            return;
        }

        // 2) 對這批文字逐筆做 location 分類
        for (const newsItem of newsTextList) {

            console.log(` =============== news_id = ${newsItem.id} =============== `);

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
    } catch (err) {
        console.error('[newsLocationWorker] 主迴圈發生錯誤：', err);
        return;
    }
    return;
}

// 直接啟動主程式
/*runLocationWorker().catch(err => {
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
});*/

module.exports = {
    runLocationWorker
}