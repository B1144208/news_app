// dataIntoSql/insertNews.js
'use strict';

const fs   = require('fs');
const path = require('path');

const pool = require('../connect_db');
const { callAndCatchApiSuccessInGeneralFunction } = require('../utils/fakeHelper');
const { batchNews } = require('../utils/batchHelper');

async function processOneFile(filePath) {
  if (!fs.existsSync(filePath)) {
    console.warn(`[insertNews] 檔案不存在，略過：${filePath}`);
    return;
  }

  const raw = fs.readFileSync(filePath, 'utf8').trim();
  if (!raw) {
    console.warn(`[insertNews] 檔案為空，刪除：${filePath}`);
    fs.unlinkSync(filePath);
    return;
  }

  let records;
  try {
    const json = JSON.parse(raw);
    // 檔案內容可能是單一物件或陣列，統一轉成陣列處理
    records = Array.isArray(json) ? json : [json];
  } catch (err) {
    console.error(`[insertNews] 解析 JSON 失敗：${filePath}，${err.message}`);
    return;
  }

  let processed = 0;
  const total = records.length;
  console.log(`[insertNews] 開始處理檔案：${filePath}，共 ${total} 筆資料`);

  while (records.length > 0) {
    // 取出前 10 筆
    const chunk = records.slice(0, 10);
    const remaining = records.slice(10);

    if (chunk.length === 0) break;

    const fakeReq = {
      body: { data: chunk }
    };

    try {
      console.log(
        `[insertNews] 準備送出 ${chunk.length} 筆（file=${path.basename(
          filePath
        )}，已處理 ${processed} / ${total}）`
      );

      // 呼叫 batchNews（不能改 batchNews 與 helper）
      await callAndCatchApiSuccessInGeneralFunction(batchNews, fakeReq);

      processed += chunk.length;
    } catch (err) {
      console.error(
        `[insertNews] 匯入失敗（file=${path.basename(
          filePath
        )}，已處理 ${processed} / ${total}）：`,
        err
      );
      // 這裡直接 throw 出去，讓外層決定要不要中止整個流程
      throw err;
    }

    // 更新剩餘資料
    records = remaining;

    if (records.length > 0) {
      // 還有剩，就覆寫回檔案（移除前 10 筆後的內容）
      fs.writeFileSync(filePath, JSON.stringify(records, null, 2), 'utf8');
      console.log(
        `[insertNews] 已刪除前 ${processed} 筆，檔案剩餘 ${records.length} 筆資料`
      );
    } else {
      // 全部處理完，刪除檔案
      fs.unlinkSync(filePath);
      console.log(`[insertNews] 檔案處理完畢並刪除：${filePath}`);
    }
  }
}

async function main() {
  try {
    // 檢查 batchNews 是否為 function
    if (typeof batchNews !== 'function') {
      throw new Error(
        '[insertNews] batchNews 不是一個函式，請檢查 batchHelper 的 export。'
      );
    }

    const newsDir = path.join(__dirname, 'news');

    // news_1.json ~ news_31.json
    const fileNames = Array.from({ length: 31 }, (_, i) => `news_${i + 1}.json`);

    for (const fileName of fileNames) {
      const filePath = path.join(newsDir, fileName);
      await processOneFile(filePath);
    }

    console.log('[insertNews] 所有檔案處理完成。');
  } catch (err) {
    console.error('[insertNews] 發生未預期錯誤：', err);
  } finally {
    if (pool && typeof pool.end === 'function') {
      try {
        await pool.end();
      } catch (e) {
        // ignore
      }
    }
    process.exit(0);
  }
}

main();
