// api/threadsWorker/newsGroupWorker.js
'use strict';

const pool = require('../connect_db');
const { newsGroupClassifier } = require('../middlewares/classifierController');
const { searchGroup } = require('../middlewares/groupController');
const { getText } = require('../middlewares/scriptController');  
const { callAndCatchApiSuccessInGeneralFunction } = require('../utils/fakeHelper');

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * 從 news_task 抓出「還沒做 group（news_group = 0）」的 news_id
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
        nt.news_keyword
      ) AS score
    FROM news_task AS nt
    JOIN news_data AS nd
      ON nd.news_id = nt.news_id
    WHERE nt.news_group = 0
    ORDER BY
      score DESC,
      nd.created_at
    LIMIT 100;
  `;

  const [rows] = await pool.query(sql);
  return rows.map(r => r.news_id);
}

/**
 * 把 classifier 回傳的 group 結果寫入 news_group 資料表
 */
async function insertNewsGroupsForOneNews(newsId, result) {
    // === 0. 先準備要查的名稱陣列，若原本就是 []，就當作 ['其他'] ===
    let namesToSearch;
    if (Array.isArray(result) && result.length > 0) {
        namesToSearch = result;
    } else {
        namesToSearch = ['其他'];
    }

    // 批次 INSERT 用的 SQL（VALUES ? 對應 mysql2 的多筆插入）
    const insertSql = `
        INSERT IGNORE INTO news_group (news_id, group_data_id, group_detail_id)
        VALUES ?
    `;

    const rowsToInsert = []; // [[newsId, dataId, detailId], ...]

    // === 1. 逐一呼叫 searchGroup，把結果整理成 {type,id} → rowsToInsert ===
    for (const rawName of namesToSearch) {
        // 空值一律當作「其他」
        const groupName = rawName || '其他';

        let searchGroupResult;
        try {
            const fakeReq = { query: { name: groupName } };
            searchGroupResult = await callAndCatchApiSuccessInGeneralFunction(searchGroup, fakeReq);
        } catch (err) {
            continue;
        }

        // 沒找到或格式不對就略過
        if (!searchGroupResult || !searchGroupResult.type || !searchGroupResult.id) {
            continue;
        }

        const { type, id } = searchGroupResult;
        let dataId = null;
        let detailId = null;

        if (type === 'data') {
            dataId = id;
        } else if (type === 'detail') {
            detailId = id;
        } else {
            // 不認得的 type 直接略過
            continue;
        }

        rowsToInsert.push([newsId, dataId, detailId]);
    }

    // === 2. 若全部 search 完還是沒有任何可用的結果，再保底塞「其他」一次 ===
    if (rowsToInsert.length === 0) {
        try {
            const fakeReq = { query: { name: '其他' } };
            const fallback = await callAndCatchApiSuccessInGeneralFunction(searchGroup, fakeReq);

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
            console.warn('[newsGroupWorker] fallback「其他」搜尋也失敗，news_id =', newsId, 'err =', err.message);
        }
    }

    // === 3. 真的完全沒有任何 row 可以寫入就結束 ===
    if (rowsToInsert.length === 0) {
        return true;
    }

    // === 4. 一次批次 INSERT IGNORE ===
    try {
        await pool.query(insertSql, [rowsToInsert]);
        return true;
    } catch (err) {
        console.warn('[newsGroupWorker] 批次寫入 news_group 失敗，news_id =', newsId, 'err =', err.message);
        return false;
    }
}


/**
 * 將單一 news 的 news_task.news_group 設為 1 （表示已完成）
 */
async function markTaskDone(newsId) {
  const sql = `
    UPDATE news_task
    SET news_group = 1
    WHERE news_id = ?;
  `;
  await pool.query(sql, [newsId]);
}

/**
 * 處理單一 news_id 的完整流程：
 * 1. 呼叫 classifier 拿到 group 結果
 * 2. 寫入 news_group
 * 3. 將 news_task.news_group 設為 1
 */
async function handleOneNews(newsItem) {
    const newsId = newsItem.id;
    const title  = newsItem.title || '';
    const body   = newsItem.text  || '';
    const newsText = `${title}\n${body}`.trim();

    const fakeReq = {
        body: { newsText: newsText }
    };

    try {
        const result = await callAndCatchApiSuccessInGeneralFunction(newsGroupClassifier, fakeReq);
        if (!result || result.success === false || !result.data) {
            console.warn( `[newsGroupWorker] news_id=${newsId} newsGroupClassifier 未正常完成，略過 markTaskDone`);
            return; // 直接跳過這筆，讓外層去跑下一個 newsId
        }
        
        const insertResult = await insertNewsGroupsForOneNews(newsId, result.data);
        if (insertResult === false) {
            console.warn(`[newsGroupWorker] news_id=${newsId} insertNewsGroupsForOneNews 回傳失敗，略過 markTaskDone`);
            return;
        }

        await markTaskDone(newsId);
    } catch (err) {
        err.desc = 'threadsWorker-newsGroup-handleOneNews(): ' + (err.message || '');
        console.error(err.desc);
    }
}

/**
 * 主迴圈：
 * - 一直從 DB 抓待處理的 idList
 * - 若有資料，逐筆處理
 * - 若沒有資料，sleep 一小時後再試
 */
async function runNewsGroupWorker() {
    console.log('[newsGroupWorker] 啟動');

    try {
        // 1) 先從 DB 抓待處理的 news_id 清單
        const idList = await fetchPendingNewsIds();

        if (idList.length === 0) {
            console.log('[newsGroupWorker] 目前沒有待處理的 news_group 任務');
            return;
        }

        // 2) 呼叫 getText，把這批 id 換成 {id, title, text} 陣列
        let newsTextList;
        try {
            const fakeReqForGetText = {
                query: { idList }
            };

            newsTextList = await callAndCatchApiSuccessInGeneralFunction(getText, fakeReqForGetText);

            // 預期格式：[{ id, title, text }, ...]
            if (!Array.isArray(newsTextList)) {
                console.warn('[newsGroupWorker] getText 回傳不是陣列，實際：', newsTextList);
                newsTextList = [];
            }
        } catch (err) {
            console.error('[newsGroupWorker] 呼叫 getText 發生錯誤：', err);
            // 避免死循環，先睡一下再重新跑 while
            await sleep(30 * 1000);
            return;
        }

        // 3) 對這批文字逐筆做 group 分類
        for (const newsItem of newsTextList) {
            if (!newsItem || typeof newsItem.id === 'undefined') {
                console.warn('[newsGroupWorker] newsItem 格式不正確，略過：', newsItem);
                continue;
            }

            try {
                await handleOneNews(newsItem); // 傳整個 {id, title, text}
            } catch (err) {
                console.error('[newsGroupWorker] 處理 news_id =', newsItem.id, '時發生錯誤：', err);
            }
        }
    } catch (err) {
        console.error('[newsGroupWorker] 主迴圈發生錯誤：', err);
        return;
    }
    return;
}

// 直接啟動主程式
runNewsGroupWorker().catch(err => {
    console.error('[newsGroupWorker] 無法啟動：', err);
    process.exit(1);
});

// 優雅關閉
process.on('SIGINT', () => {
    console.log('\n[newsGroupWorker] 收到 SIGINT，準備結束');
    process.exit(0);
});

process.on('SIGTERM', () => {
    console.log('\n[newsGroupWorker] 收到 SIGTERM，準備結束');
    process.exit(0);
});

module.exports = {
    runNewsGroupWorker
}