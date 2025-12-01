// api/threadsWorker/newsGroupWorker.js
'use strict';

const pool = require('../connect_db');
const { newsGroupClassifier } = require('../middlewares/classifierController');
const { searchGroup } = require('../middlewares/groupController');
const { getText } = require('../middlewares/scriptController');  
const { callAndCatchApiSuccessInGeneralFunction } = require('../utils/fakeHelper');

const SLEEP_WHEN_EMPTY_MS = 60 * 60 * 1000;
const SHORT_SLEEP_MS = 5 * 1000;

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * 從 news_task 抓出「還沒做 group（news_group = 0）」的 news_id
 * 依照五個欄位的加總分數由大到小排序，再依照 created_at 越新越前面
 * 一次最多抓 10 筆
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
    LIMIT 10;
  `;

  const [rows] = await pool.query(sql);
  return rows.map(r => r.news_id);
}

/**
 * 把 classifier 回傳的 group 結果寫入 news_group 資料表
 */
async function insertNewsGroupsForOneNews(newsId, result) {

    console.log("5. result: ", result, "\n");

    // 沒有結果就直接結束
    if (!Array.isArray(result) || result.length === 0) {
        console.log('[newsGroupWorker] news_id =', newsId, '沒有任何 group，標記完成');
        return;
    }

    const insertSql = `
        INSERT IGNORE INTO news_group (news_id, group_data_id, group_detail_id)
        VALUES (?, ?, ?)
    `;


    console.log("6. groupName: ")
    for (const rawName of result) {
        // 空值就當成「其他」
        const groupName = rawName || '其他';

        console.log("\t", groupName);

        let searchGroupResult;
        try {
            // searchGroup 用的是 req.query.name
            const fakeReq = {
                query: { name: groupName }
            };

            searchGroupResult = await callAndCatchApiSuccessInGeneralFunction(searchGroup, fakeReq);

            console.log("6-2. searchGroupResult: ", searchGroupResult);
        } catch (err) {
            console.warn('[newsGroupWorker] 搜尋 group 失敗，news_id =', newsId, 'name =', groupName, 'err =', err.message);
            // 這個標籤失敗就跳過，處理下一個
            continue;
        }
        console.log("7. searchGroupResult, searchGroupResult.success, searchGroupResult.data: ", searchGroupResult, searchGroupResult.success, searchGroupResult.data);

        // 沒找到或 success === false 就略過
        if (!searchGroupResult || searchGroupResult.success === false || !searchGroupResult.data) {
            continue;
        }

        console.log("8. 888888888 ");

        const { type, id } = searchGroupResult.data || {};
        let dataId = null;
        let detailId = null;

        console.log("9. type, id: ", type, id);

        if (type === 'data') {
            dataId = id;
        } else if (type === 'detail') {
            detailId = id;
        } else {
            continue;
        }
        let params = [newsId, dataId, detailId];
        console.log("10. params: ", params);
        try {
            let [result] = await pool.query(insertSql, parmas);
            console.log("11. insertSql result: ", result);
        } catch (err) {
            console.warn("err for insertSql: ", err.message);
        }
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

    console.log('[newsGroupWorker] 開始處理 news_id =', newsId);

    // 組成送進模型的文字：標題 + 內文
    const newsText = `${title}\n${body}`.trim();

    const fakeReq = {
        body: { newsText: newsText }
    };

    try {
        const result = await callAndCatchApiSuccessInGeneralFunction(newsGroupClassifier, fakeReq);
        console.log("4. result: ", result, "\n");
        await insertNewsGroupsForOneNews(newsId, result.data);
        await markTaskDone(newsId);
    } catch (err) {
        err.desc = 'threadsWorker-newsGroup-handleOneNews(): ' + (err.message || '');
        console.error(err.desc);
    }

    console.log('[newsGroupWorker] 完成 news_id =', newsId);
}

/**
 * 主迴圈：
 * - 一直從 DB 抓待處理的 idList
 * - 若有資料，逐筆處理
 * - 若沒有資料，sleep 一小時後再試
 */
async function mainLoop() {
  console.log('[newsGroupWorker] 啟動');

    while (true) {
        try {
        // 1) 先從 DB 抓待處理的 news_id 清單
        const idList = await fetchPendingNewsIds();

        console.log(idList);

        if (idList.length === 0) {
            console.log('[newsGroupWorker] 目前沒有待處理的 news_group 任務，睡一小時再檢查');
            await sleep(SLEEP_WHEN_EMPTY_MS);
            continue;
        }

        console.log('[newsGroupWorker] 本輪取得', idList.length, '筆任務：', idList.join(', '));

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
            continue;
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
            console.error(
                '[newsGroupWorker] 處理 news_id =',
                newsItem.id,
                '時發生錯誤：',
                err
            );
            // 單筆錯就寫 log，繼續處理下一筆
            }

            // 稍微休息一下，避免瞬間打太多 DB / 模型請求
            // await sleep(SHORT_SLEEP_MS);
        }

        // 一輪跑完，立刻再去 DB 抓新的一輪
        console.log('[newsGroupWorker] 本輪處理完畢，重新抓取任務...');
        } catch (err) {
            console.error('[newsGroupWorker] 主迴圈發生錯誤：', err);
            // 發生非預期錯誤時，避免死循環瘋狂重試，先睡一下再繼續
            await sleep(30 * 1000);
        }
    }
}

// 直接啟動主程式
mainLoop().catch(err => {
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

