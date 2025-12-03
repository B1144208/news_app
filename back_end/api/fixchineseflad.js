// fixchineseflad.js

// ❗ 根據您的專案結構 (eventsortingController.js)，引入資料庫連線池
// ❗ 假設連線池檔案位於上一層目錄 (../connect_db)
const pool = require('./connect_db');

// --- 1. 中文檢查函數 (hasChinese) ---
/**
 * 檢查字串是否包含中文。
 * @param {string} str - 要檢查的字串。
 * @returns {number} 1 表示包含中文，0 表示不包含中文 (或非字串)。
 */
function hasChinese(str) {
    if (typeof str !== 'string') return 0;

    // 判斷是否包含任何一個中文 (主要漢字區和擴展區)
    const chineseRegex = /[\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF]/;
    return chineseRegex.test(str) ? 1 : 0; // 1: 中文, 0: 非中文/英文
}

// --- 2. 修正函數 (syncAllChineseFlags) ---
/**
 * 全面檢查並同步 news_data 表格中所有新聞的 is_chinese 標記。
 * 步驟：1. 查詢所有新聞。 2. 重新檢查標題並更新 is_chinese 標記。
 * @param {object} pool - 資料庫連線池 (Connection Pool)
 */
async function syncAllChineseFlags(pool) {
    console.log("🚀 開始全面檢查並同步所有新聞的 is_chinese 標記...");
    let updateCount = 0;

    try {
        // --- 步驟 1: 查詢所有新聞 (只取 ID 和 Title) ---
        // 為了效能，可以只選取 news_id, news_title, 和 current is_chinese (current_flag)
        const selectSql = `
            SELECT
                news_id,
                news_title,
                is_chinese AS current_flag
            FROM
                news_data;
        `;

        const [allNews] = await pool.query(selectSql);
        console.log(`總共找到 ${allNews.length} 條新聞需要檢查。`);

        // --- 步驟 2: 遍歷、檢查並更新 ---
        const updatePromises = allNews.map(async (news) => {
            const { news_id, news_title, current_flag } = news;

            // 執行檢查，結果為 1 (中文) 或 0 (非中文/英文)
            const expectedIsChinese = hasChinese(news_title);

            // 優化: 只有當期望值與現有值不同時，才執行 UPDATE
            if (expectedIsChinese !== current_flag) {
                const updateSql = `
                    UPDATE
                        news_data
                    SET
                        is_chinese = ?
                    WHERE
                        news_id = ?;
                `;

                const [result] = await pool.query(updateSql, [expectedIsChinese, news_id]);

                if (result.changedRows > 0) {
                     updateCount++;
                     const action = expectedIsChinese === 1 ? '由 0 修正為 1 (中文)' : '由 1 修正為 0 (非中文)';
                     console.log(`[修正] ID: ${news_id}, 動作: ${action}。`);
                }
            }
        });

        // 等待所有更新操作完成
        await Promise.all(updatePromises);

        console.log(`\n✅ 同步完成！總共修正了 ${updateCount} 條新聞的 is_chinese 標記。`);

    } catch (err) {
        console.error("❌ 同步 is_chinese 標記時發生致命錯誤:", err);
        // 拋出錯誤讓主函數處理
        throw err;
    }
}


// --- 3. 執行主函數 ---
async function main() {
    try {
        // 呼叫同步函數
        await syncAllChineseFlags(pool);

    } catch (error) {
        console.error("\n*** ⚠️ 程式執行失敗 ***\n", error.message);
    }
    // 注意：這裡假設您的 connect_db.js 匯出的是共用連線池，通常不用關閉。
    // 如果您需要在腳本執行結束時強制關閉，請確保 pool 有 end 方法。
}

// 開始執行
main();