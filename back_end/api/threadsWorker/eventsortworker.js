// threads/event_sorter.js (CommonJS 格式 - DB 輔助函式已內建)

const pool = require('../connect_db'); // 從根目錄引入連線池
const { ollamaSummarize } = require('../utils/ollama_client');
const { getEmbedding, findSimilarEvents } = require('../utils/embeddingHelper');

// --- 配置與任務狀態 ---
const POLLING_INTERVAL_MS = 10000;
const TASK_STATUS_COMPLETED = 1;
const TASK_STATUS_FAILED = 2;

// ========================================================
// I. 內部定義資料庫輔助函式
// ========================================================

/** 抓取待處理的 relation_id (eventsoring_text = 0) */
async function getPendingRelationIds() {
    const [rows] = await pool.query(
        `SELECT relation_id FROM relation_task WHERE eventsoring_text = 0`
    );
    return rows.map(row => row.relation_id);
}

/** 取得事件相關的新聞 ID，並依照時間升序排序 */
async function getNewsIdsByRelationId(relationId) {
    const sql = `
        SELECT t1.news_id
        FROM relation_news_link AS t1
        JOIN news_data AS t2 ON t1.news_id = t2.news_id
        WHERE t1.relation_id = ?
        ORDER BY t2.news_publish_time ASC
    `;
    const [rows] = await pool.query(sql, [relationId]);
    return rows.map(row => row.news_id);
}

/** 根據新聞 ID 獲取新聞文本 (標題 + 內文) */
async function getNewsTextsByIds(idList) {
    if (!idList || idList.length === 0) return [];

    const sql = `
        SELECT news_title, news_text
        FROM news_data
        WHERE news_id IN (?)
        ORDER BY news_id
    `;

    const [rows] = await pool.query(sql, [idList]);

    return rows.map(row =>
        `標題: ${row.news_title}\n內文: ${row.news_text}`
    );
}

/** 儲存/更新 eventsorting_data (title, summary, embedding) */
async function upsertEventSortingData({ eventsorting_id, title, summary, embeddingJson }) {
    const sql = `
        INSERT INTO eventsorting_data (eventsorting_id, title, summary, embedding_json)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            title = VALUES(title),
            summary = VALUES(summary),
            embedding_json = VALUES(embedding_json),
            updated_at = NOW()
    `;
    await pool.query(sql, [eventsorting_id, title, summary, embeddingJson]);
}

/** 儲存 Eventsorting Vertical (新聞時間線) */
async function saveEventsortingVertical(relationId, sequence) {
    await pool.query(`DELETE FROM eventsorting_vertical WHERE eventsorting_id = ?`, [relationId]);
    if (sequence.length > 0) {
        const values = sequence.map(item => [relationId, item.news_id, item.sequence_order]);
        const sql = `INSERT INTO eventsorting_vertical (eventsorting_id, news_id, sequence_order) VALUES ?`;
        await pool.query(sql, [values]);
    }
}

/** 儲存 Eventsorting Horizontal (相關事件連結) */
async function saveEventsortingHorizontal(relationId, relatedEvents) {
    await pool.query(`DELETE FROM eventsorting_horizontal WHERE eventsorting_id = ?`, [relationId]);
    if (relatedEvents.length > 0) {
        const values = relatedEvents.map(item => [relationId, item.related_eventsorting_id]);
        const sql = `INSERT INTO eventsorting_horizontal (eventsorting_id, related_eventsorting_id) VALUES ?`;
        await pool.query(sql, [values]);
    }
}

/** 更新 relation_task 狀態 */
async function updateRelationTaskStatus(relationId, status) {
    await pool.query(
        `UPDATE relation_task SET eventsoring_text = ?, updated_at = NOW() WHERE relation_id = ?`,
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

        // 取得新聞全文並合併
        const newsTexts = await getNewsTextsByIds(newsIds);
        const combinedNewsText = newsTexts.join('\n\n--- [新聞分隔線] ---\n\n');

        // 呼叫 Ollama 模型
        const { title, summary } = await ollamaSummarize('eventsorting_model', combinedNewsText);

        // 取得 Embedding 向量
        const embedding = await getEmbedding(title + ' ' + summary);
        const embeddingJson = JSON.stringify(embedding);

        // 儲存事件摘要與向量
        await upsertEventSortingData({
            eventsorting_id: relationId,
            title,
            summary,
            embeddingJson
        });

        // 儲存 Vertical (時間線)
        const verticalSequence = analyzeChronology(newsIds);
        await saveEventsortingVertical(relationId, verticalSequence);

        // 儲存 Horizontal (相關事件連結)
        const relatedIds = await findSimilarEvents(embedding, relationId, 0.75);
        await saveEventsortingHorizontal(relationId, relatedIds.map(id => ({ related_eventsorting_id: id })));

        // 完成任務
        await updateRelationTaskStatus(relationId, TASK_STATUS_COMPLETED);
        console.log(`[SUCCESS] 事件 ID: ${relationId} 處理完成，eventsoring_text 設為 1。`);

    } catch (error) {
        console.error(`[FATAL] 處理事件 ID ${relationId} 時發生嚴重錯誤:`, error.message);
        // 確保錯誤時將狀態設為失敗，避免無限重試
        await updateRelationTaskStatus(relationId, TASK_STATUS_FAILED);
    }
}


/** 核心執行緒主循環 (Main Loop) */
async function mainLoop() {
    console.log("--- 事件整理背景服務啟動 ---");
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

// 啟動主循環
mainLoop();