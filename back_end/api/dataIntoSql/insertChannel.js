// dataIntoSql/insertChannel.js
'use strict';

const fs   = require('fs');
const path = require('path');

const pool = require('../connect_db');
const { callAndCatchApiSuccessInGeneralFunction } = require('../utils/fakeHelper');
const { batchChannel } = require('../utils/batchHelper');

async function main() {
  try {
    // 檢查 batchChannel 是否真的是一個 function
    if (typeof batchChannel !== 'function') {
      throw new Error('[insertChannel] batchChannel 不是一個函式，請檢查 channelController 的 export。');
    }

    const channelDir = path.join(__dirname, 'channel');

    // 目前要匯入的檔案清單（之後要加更多就直接加在這裡）
    const fileNames = [
      'channel_1.json'
    ];

    const data = [];

    // 逐一讀檔並 parse JSON
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

      // 檔案裡可能是 array 也可能是單一物件
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

    console.log('[insertChannel] 準備送出資料筆數：', data.length);

    // 準備 fakeReq 給 batchChannel（跟一般 Express controller 一樣的介面）
    const fakeReq = {
      body: { data }
    };

    // 這裡用通用 helper 來呼叫 controller
    const resultData = await callAndCatchApiSuccessInGeneralFunction(batchChannel, fakeReq);

    // 根據你的 batchChannel 回傳格式做檢查：
    // 假設 batchChannel 的 res.apiSuccess(data, message) 裡的 data 就是我們要的東西
    if (!resultData) {
      console.warn('[insertChannel] batchChannel 沒有回傳任何資料（resultData 為 falsy），仍視為成功結束。');
    } else {
      console.log('[insertChannel] 匯入成功，controller 回傳：', resultData);
    }

    console.log('[insertChannel] 匯入成功，開始刪除 JSON 檔案。');

    // 只在匯入成功之後刪檔
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
