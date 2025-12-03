// fixchineseflad.js

// ❗ 根據您的 eventsortingController.js 參考，我們使用 require 引入連線池
// ❗ 假設 connect_db.js 就在與 api 目錄同級的目錄，如果不是，請調整路徑
const pool = require('./connect_db');

// 這裡定義的 pool 變數就是連線池物件了，它在 fixChineseFlags 函數執行時可以被存取。


// --- 1. 中文檢查函數 (hasChinese) ---
function hasChinese(str) {
    if (typeof str !== 'string') return 0;
    const chineseRegex = /[\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF]/;
    return chineseRegex.test(str) ? 1 : 0;
}

// --- 2. 修正函數 (fixChineseFlags) ---
async function fixChineseFlags(pool) {
    console.log("🚀 開始檢查並修正舊新聞的 is_chinese 標記...");
    let updateCount = 0;

    try {
        const selectSql = `SELECT news_id, news_title FROM news_data WHERE is_chinese = 0`;
        const [newsToVerify] = await pool.query(selectSql);

        console.log(`總共找到 ${newsToVerify.length} 條新聞需要重新檢查標記 (is_chinese=0)。`);

        const updatePromises = newsToVerify.map(async (news) => {
            if (hasChinese(news.news_title) === 1) {
                const updateSql = `UPDATE news_data SET is_chinese = 1 WHERE news_id = ?`;
                await pool.query(updateSql, [news.news_id]);
                updateCount++;
            }
        });

        await Promise.all(updatePromises);
        console.log(`✅ 修正完成！總共更新了 ${updateCount} 條新聞的 is_chinese 標記。`);

    } catch (err) {
        console.error("❌ 修正 is_chinese 標記時發生錯誤:", err);
        throw err;
    }
}


// --- 3. 執行主函數 ---
async function main() {
    try {
        // 呼叫修正函數
        await fixChineseFlags(pool);

    } catch (error) {
        console.error("\n*** ⚠️ 程式執行失敗 ***\n", error.message);
    }
    // 注意：這裡通常不需要 pool.end()，因為 connect_db 匯出的可能是共用的連線池，
    // 如果您確認 fixchineseflad.js 是獨立運行，且需要關閉連線，則可以加上。
    // 如果不關閉，程式會在執行完成後保持連線直到逾時。
    // 如果需要關閉，pool 必須是您從 connect_db 拿到的完整 pool 物件。
    // 為了安全，我們暫時不加 pool.end()。
}

main(); // 開始執行

// 為了讓 node 知道這是一個 CommonJS 模組，您可能需要：
// 1. 確保 package.json 中沒有 "type": "module"
// 2. 執行時使用 `node fixchineseflad.js` (您已經這樣做了)