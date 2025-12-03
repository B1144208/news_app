/**
 * 修正舊新聞中錯誤的 is_chinese 標記
 * 步驟：1. 查詢 is_chinese=0 的新聞。 2. 重新檢查標題。 3. 更新錯誤的標記。
 * @param {object} pool - 資料庫連線池 (Connection Pool)
 */
async function fixChineseFlags(pool) {
    console.log("🚀 開始檢查並修正舊新聞的 is_chinese 標記...");
    let updateCount = 0;

    try {
        // --- 步驟 1: 查詢所有 is_chinese = 0 的新聞（只取ID和Title） ---
        const selectSql = `
            SELECT
                news_id,
                news_title
            FROM
                news_data
            WHERE
                is_chinese = 0;
        `;

        const [newsToVerify] = await pool.query(selectSql);
        console.log(`總共找到 ${newsToVerify.length} 條新聞需要重新檢查標記 (is_chinese=0)。`);

        // --- 步驟 2 & 3: 遍歷並更新 ---
        const updatePromises = newsToVerify.map(async (news) => {
            const { news_id, news_title } = news;

            // 重新檢查標題是否包含中文
            const newIsChinese = hasChinese(news_title);

            // 如果發現它應該是中文 (newIsChinese === 1)，但現在是 0，就進行更新
            if (newIsChinese === 1) {
                const updateSql = `
                    UPDATE
                        news_data
                    SET
                        is_chinese = 1
                    WHERE
                        news_id = ?;
                `;

                await pool.query(updateSql, [news_id]);
                updateCount++;
                console.log(`[修正] News ID: ${news_id} 的標記已由 0 修正為 1 (標題: "${news_title.substring(0, 20)}...")`);
            }
        });

        // 等待所有更新操作完成
        await Promise.all(updatePromises);

        console.log(`✅ 修正完成！總共更新了 ${updateCount} 條新聞的 is_chinese 標記。`);

    } catch (err) {
        console.error("❌ 修正 is_chinese 標記時發生錯誤:", err);
        throw new Error('Batch update error during is_chinese correction');
    }
}

// 呼叫範例 (假設您已經設定好 pool)：
await fixChineseFlags(pool);