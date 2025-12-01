// dataIntoSql/insertChannel.js
'use strict';

const fs   = require('fs');
const path = require('path');

const pool = require('../connect_db');
const { checkRequireField } = require('../utils/checkHelper'); // 先保留引用，以後要檢查欄位可以用
const { callAndCatchApiSuccessInGeneralFunction } = require('../utils/fakeHelper');
const { batchChannel } = require('../middlewares/channelController');

async function main () {
  try {
    const channelDir = path.join(__dirname, 'channel');

    // 要讀的檔名
    const fileNames = [
      'channel_1.json'
    ];

    const data = [];

    // 逐一讀檔 + parse JSON
    for (const fileName of fileNames) {
      const filePath = path.join(channelDir, fileName);

      if (!fs.existsSync(filePath)) {
        console.warn(`[insertChannel] 檔案不存在，略過：${filePath}`);
        continue;
      }

      const raw = fs.readFileSync(filePath, 'utf8').trim();
      if (!raw) {
        console.warn(`[insertChannel] 檔案為空，略過：${filePath}`);
        continue;
      }

      let json;
      try {
        json = JSON.parse(raw);
      } catch (err) {
        console.error(`[insertChannel] 解析 JSON 失敗：${filePath}`, err.message);
        continue;
      }

      // 檔案裡可能是 array 也可能是一個物件
      if (Array.isArray(json)) {
        data.push(...json);
      } else {
        data.push(json);
      }
    }

    if (data.length === 0) {
      console.log('[insertChannel] 沒有任何資料可匯入，程式結束。');
      return;
    }

    // 準備 fakeReq 傳給 batchChannel
    const fakeReq = {
      body: { data }
    };

    console.log('[insertChannel] 準備送出資料筆數：', data.length);

    const result = await callAndCatchApiSuccessInGeneralFunction(batchChannel, fakeReq);

    // 視你的 callAndCatchApiSuccessInGeneralFunction 回傳格式而定，這裡做個保守檢查
    if (!result || result.success === false) {
      console.error('[insertChannel] 呼叫 batchChannel 失敗：', result);
      return;
    }

    console.log('[insertChannel] 匯入成功，開始刪除 JSON 檔案。');

    // 只在匯入成功後刪檔
    for (const fileName of fileNames) {
      const filePath = path.join(channelDir, fileName);
      if (!fs.existsSync(filePath)) continue;

      try {
        fs.unlinkSync(filePath);
        console.log(`[insertChannel] 已刪除：${filePath}`);
      } catch (err) {
        console.error(`[insertChannel] 刪除檔案失敗：${filePath}`, err.message);
      }
    }

    console.log('[insertChannel] 全部完成。');
  } catch (err) {
    console.error('[insertChannel] 發生未預期錯誤：', err);
  } finally {
    // 如果有需要關閉 pool，可以保留這段
    if (pool && pool.end) {
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
