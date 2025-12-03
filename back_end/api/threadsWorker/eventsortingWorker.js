// back_end/api/threadsWorker/eventsortingWorker.js
// 這是事件整理的主 Worker，負責排程、DB 操作，並呼叫 LLM 服務進行摘要和 Embedding。

// 修正路徑: 從 'threadsWorker/' 回溯一級到 'api/'，找到 connect_db.js
const pool = require('../connect_db');
// 變更: 引入 OpenAI 摘要服務 (新檔案)
const { openaiSummarize } = require('../utils/event_openai_client');
// 維持不變: 引入您現有的 Embedding 輔助函式 (假設路徑正確且功能不變)
const { getEmbedding, findSimilarEvents } = require('../utils/embeddingHelper');

// --- 配置與任務狀態 ---
const POLLING_INTERVAL_MS = 10000;
const DATABASE_RETRY_INTERVAL_MS = 5000;
const TASK_STATUS_COMPLETED = 1;
const TASK_STATUS_FAILED = 2;
// 變更: 使用 OpenAI 模型名稱
const MODEL_NAME = 'gpt-4o-mini';

// ========================================================
// I. 內部定義資料庫輔助函式
// ========================================================

/** 抓取待處理的 relation_id (eventsoring_text = 0) */
async function getPendingRelationIds() {
    const [rows] = await pool.query(
        `SELECT relation_id FROM relation_task WHERE eventsorting_text = 0`
    );
    return rows.map(row => row.relation_id);
}

/** 取得事件相關的新聞 ID，並依照時間升序排序 */
async function getNewsIdsByRelationId(relationId) {
    const sql = `
        SELECT news_id
        FROM news_data
        WHERE relation_id = ?
        ORDER BY news_date ASC
    `;
    const [rows] = await pool.query(sql, [relationId]);
    return rows.map(row => row.news_id);
}

/** 根據新聞 ID 獲取新聞文本 (標題 + 內文) */
async function getNewsTextsByIds(idList) {
    if (!idList || idList.length === 0) return [];

    const placeholders = idList.map(() => '?').join(',');

    const sql = `
        SELECT
            t1.news_title,
            GROUP_CONCAT(t2.body_text ORDER BY t2.body_order SEPARATOR '') AS news_text
        FROM news_data AS t1
        JOIN news_body AS t2 ON t1.news_id = t2.news_id
        WHERE t1.news_id IN (${placeholders}) AND t2.body_type = 'text'
        GROUP BY t1.news_id, t1.news_title
        ORDER BY FIELD(t1.news_id, ${placeholders})
    `;

    const params = [...idList, ...idList];

    const [rows] = await pool.query(sql, params);

    return rows.map(row =>
        `標題: ${row.news_title}\n內文: ${row.news_text}`
    );
}

/** 儲存/更新 eventsorting_data (title, summary, embedding) */
async function upsertEventSortingData({ eventsorting_id, title, summary, eventsorting_embedding_data }) {
    const sql = `
        INSERT INTO eventsorting_data (eventsorting_id, eventsorting_title, eventsorting_summary, eventsorting_embedding)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            eventsorting_title = VALUES(eventsorting_title),
            eventsorting_summary = VALUES(eventsorting_summary),
            eventsorting_embedding = VALUES(eventsorting_embedding),
            updated_at = NOW()
    `;
    await pool.query(sql, [eventsorting_id, title, summary, eventsorting_embedding_data]);
}

/** 儲存 Eventsorting Vertical (新聞時間線) */
async function saveEventsortingVertical(relationId, sequence) {
    await pool.query(`DELETE FROM eventsorting_vertical WHERE eventsorting_id = ?`, [relationId]);
    if (sequence.length > 0) {
        const values = sequence.map(item => [relationId, item.news_id]);
        const sql = `INSERT INTO eventsorting_vertical (eventsorting_id, news_id) VALUES ?`;
        await pool.query(sql, [values]);
    }
}

/** 儲存 Eventsorting Horizontal (相關事件連結) */
async function saveEventsortingHorizontal(relationId, relatedEvents) {
    await pool.query(`DELETE FROM eventsorting_horizontal WHERE eventsorting_id = ?`, [relationId]);

    if (relatedEvents.length === 0) return;

    const values = [];
    const existingPairs = new Set();

    for (const item of relatedEvents) {
        const relatedId = item.related_eventsorting_id;

        const smallerId = Math.min(relationId, relatedId);
        const largerId = Math.max(relationId, relatedId);

        const pairKey = `${smallerId}-${largerId}`;

        if (!existingPairs.has(pairKey)) {
            values.push([smallerId, largerId]);
            existingPairs.add(pairKey);
        }
    }

    if (values.length > 0) {
        const sql = `INSERT IGNORE INTO eventsorting_horizontal (eventsorting_id, horizontal_id) VALUES ?`;
        await pool.query(sql, [values]);
    }
}

async function updateRelationTaskStatus(relationId, status) {
    await pool.query(
        `UPDATE relation_task SET eventsorting_text = ? WHERE relation_id = ?`,
        [status, relationId]
    );
}

// ========================================================
// II. 核心業務邏輯
// ========================================================

/** 決定新聞的順序 (因 DB 查詢已排序，這裡僅分配順序號) */
function analyzeChronology(newsIds) {
    return newsIds.map((id, index) => ({ news_id: id, sequence_order: index + 1 }));
}

/** 處理單一 relation_task 的事件整理工作 */
async function processTask(relationId) {
    try {
        console.log(`\n[START] 處理事件 ID: ${relationId}`);

        const newsIds = await getNewsIdsByRelationId(relationId);
        if (newsIds.length === 0) {
            console.warn(`事件 ${relationId} 未連結任何新聞，標記為完成 (無內容)。`);
            await updateRelationTaskStatus(relationId, TASK_STATUS_COMPLETED);
            return;
        }

        const newsTexts = await getNewsTextsByIds(newsIds);
        const combinedNewsText = newsTexts.join('\n\n--- [新聞分隔線] ---\n\n');

        // ==== 摘要指令 ====
        const instruction = `請根據以下多篇新聞內容，創作一個簡潔、清晰且不超過400字的事件摘要(eventsorting_summary)，以及一個包含關鍵資訊但不超過30字的標題(eventsorting_title)。你的輸出必須是原創的、濃縮的內容，禁止直接複製貼上任何一篇新聞的原文。`;
        const promptWithInstruction = `${instruction}\n\n--- [新聞內容開始] ---\n\n${combinedNewsText}`;

        // 呼叫 OpenAI 模型 (摘要)
        console.log(`[OpenAI] 呼叫模型 ${MODEL_NAME} 進行摘要...`);

        const { title = '', summary = '' } = await openaiSummarize(MODEL_NAME, promptWithInstruction) || {};

        if (title.length < 5 || summary.length < 10) {
            console.error(`[OpenAI Error] 事件 ID ${relationId}: 模型返回摘要內容不足 (Title: ${title.length}, Summary: ${summary.length})，標記為失敗。`);
            await updateRelationTaskStatus(relationId, TASK_STATUS_FAILED);
            return;
        }

        // 取得 Embedding 向量 (使用您現有的 getEmbedding 函式)
        const embedding = await getEmbedding(title + ' ' + summary);

        if (!embedding || embedding.length === 0) {
            console.error(`[Embedding Error] 事件 ID ${relationId}: 無法獲取 Embedding 向量，標記為失敗。`);
            await updateRelationTaskStatus(relationId, TASK_STATUS_FAILED);
            return;
        }

        const eventsorting_embedding_data = JSON.stringify(embedding);

        // 儲存事件摘要與向量
        await upsertEventSortingData({
            eventsorting_id: relationId,
            title,
            summary,
            eventsorting_embedding_data
        });

        // 儲存 Vertical (時間線)
        const verticalSequence = analyzeChronology(newsIds);
        await saveEventsortingVertical(relationId, verticalSequence);

        // 儲存 Horizontal (相關事件連結)
        const threshold = 0.7;
        // 使用您現有的 findSimilarEvents 函式
        const relatedIds = await findSimilarEvents(embedding, relationId, threshold);
        await saveEventsortingHorizontal(relationId, relatedIds.map(id => ({ related_eventsorting_id: id })));

        // 完成任務
        await updateRelationTaskStatus(relationId, TASK_STATUS_COMPLETED);
        console.log(`[SUCCESS] 事件 ID: ${relationId} 處理完成，eventsoring_text 設為 1。`);

    } catch (error) {
        // 確保捕獲任何來自 LLM 服務或資料庫的錯誤
        console.error(`[FATAL] 處理事件 ID ${relationId} 時發生嚴重錯誤:`, error.message);
        await updateRelationTaskStatus(relationId, TASK_STATUS_FAILED);
    }
}


/** 等待資料庫連線成功 */
async function waitForDatabaseConnection() {
    while (true) {
        let connection;
        try {
            console.log('[DB Check] 嘗試獲取資料庫連線...');
            connection = await pool.getConnection();
            console.log('✅ [DB Check] 資料庫連線成功！');
            connection.release();
            return;
        } catch (error) {
            console.error(`❌ [DB Error] 資料庫連線失敗: ${error.message}. 請確認 MySQL 服務已啟動且設定正確。將在 ${DATABASE_RETRY_INTERVAL_MS / 1000} 秒後重試...`);
        } finally {
            if (connection) {
                connection.release();
            }
        }
        await new Promise(resolve => setTimeout(resolve, DATABASE_RETRY_INTERVAL_MS));
    }
}


/** 核心執行緒主循環 (Main Loop) */
async function mainLoop() {
    await waitForDatabaseConnection();

    console.log(`--- 事件整理背景服務啟動 (常駐模式 - 使用 ${MODEL_NAME} 進行摘要) ---`);
    while (true) {
        try {
            const pendingTasks = await getPendingRelationIds();

            if (pendingTasks.length > 0) {
                console.log(`\n=> 發現 ${pendingTasks.length} 個待處理任務。`);

                for (const relationId of pendingTasks) {
                    await processTask(relationId);
                }
            } else {
                process.stdout.write(`[IDLE] 暫無新任務。正在等待... (${POLLING_INTERVAL_MS/1000}s) \r`);
            }
        } catch (error) {
            console.error("\n[MAIN LOOP ERROR] 主循環發生嚴重錯誤:", error.message);
        }

        await new Promise(resolve => setTimeout(resolve, POLLING_INTERVAL_MS));
    }
}

// ========================================================
// III. 程式啟動邏輯：單次執行 或 常駐循環
// ========================================================

const targetId = process.argv[2];

if (targetId && !isNaN(parseInt(targetId))) {
    const eventId = parseInt(targetId);
    console.log(`\n[MODE] 單次執行模式: 處理事件 ID ${eventId}`);

    // 單次執行模式也需要先檢查資料庫連線
    waitForDatabaseConnection().then(() => {
        processTask(eventId)
            .catch(err => {
                console.error(`單次任務執行失敗:`, err.message);
            })
            .finally(() => {
                console.log(`[DONE] ID ${eventId} 處理完畢，程序退出。`);
                process.exit(0);
            });
    }).catch(err => {
        console.error(`無法連線到資料庫，單次任務無法啟動:`, err.message);
        process.exit(1);
    });

} else {
    // 沒有提供有效的 ID，進入常駐循環模式
    mainLoop();
}