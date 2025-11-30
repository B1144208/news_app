// api/threadsWorker/newsGroupWorker.js
'use strict';

const pool = require('../connect_db');
const { newsGroupClassifier } = require('../middlewares/classifierController');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');

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
    if (!result || !Array.isArray(result.group)) {
        console.warn('[newsGroupWorker] news_id =', newsId, '回傳 group 格式不正確，略過寫入');
        return;
    }

    const groups = result.group;

    if (groups.length === 0) {
        console.log('[newsGroupWorker] news_id =', newsId, '沒有任何 group，仍標記為完成');
        return;
    }

    const insertSql = `
        INSERT INTO news_group (news_id, group_data_id, group_detail_id)
        VALUES (?, ?, ?);
  `;

    for (const g of groups) {
        let dataId = null;
        let detailId = null;

        if (g.type === 'data') {
            dataId = g.id;
        } else if (g.type === 'detail') {
            detailId = g.id;
        } else {
            console.warn('[newsGroupWorker] news_id =', newsId, '遇到未知的 group.type =', g.type, '，略過這筆 group');
            continue;
        }

        await pool.query(insertSql, [newsId, dataId, detailId]);
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
async function handleOneNews(newsId) {
    console.log('[newsGroupWorker] 開始處理 news_id =', newsId);
    let fakeReq = {
        body: { newsId }
    };
    try {
        let result = await callAndCatchApiSuccess(newsGroupClassifier, fakeReq);
        await insertNewsGroupsForOneNews(newsId, result);
        await markTaskDone(newsId);
    } catch (err) {
        err.desc = "threadsWorker-newsGroup-handleOneNews(): "
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
            const idList = await fetchPendingNewsIds();

            if (idList.length === 0) {
                console.log('[newsGroupWorker] 目前沒有待處理的 news_group 任務，睡一小時再檢查');
                await sleep(SLEEP_WHEN_EMPTY_MS);
                continue;
            }

            console.log(
                '[newsGroupWorker] 本輪取得',
                idList.length,
                '筆任務：',
                idList.join(', ')
            );

            for (const newsId of idList) {
                try {
                await handleOneNews(newsId);
                } catch (err) {
                console.error(
                    '[newsGroupWorker] 處理 news_id =',
                    newsId,
                    '時發生錯誤：',
                    err
                );
                // 單筆錯就寫 log，繼續處理下一筆
                }

                // 稍微休息一下，避免瞬間打太多 DB / 模型請求
                await sleep(SHORT_SLEEP_MS);
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

