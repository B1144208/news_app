// threadsWorker/newsMainWorker.js
'use strict';

const pool = require('../connect_db');
const { runGroupWorker }    = require('./newsGroupWorker');
const { runLocationWorker } = require('./newsLocationWorker');
const { runKeywordWorker }  = require('./newsKeywordWorker');

const SLEEP_IF_IDLE_MS = 60 * 60 * 1000; // 1 小時
const SLEEP_IF_REST_MS = 5 * 60 * 1000;  // 5 分鐘
const IDLE_THRESHOLD_MS = 3 * 1000;     // 20 秒

const LIMIT = 50;

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// 主迴圈
async function mainLoop() {
  console.log('[newsMainWorker] 啟動');

    while (true) {

        const loopStart = Date.now();

        try { await runAllWorker(LIMIT); } 
        catch (err) { console.warn('[newsMainWorker] all-worker error, news_id =', err.message); }
        await sleep(SLEEP_IF_REST_MS);
        
        const loopEnd = Date.now();
        const elapsedMs = loopEnd - loopStart;
        const elapsedSec = (elapsedMs / 1000).toFixed(2);

        
        if (elapsedMs <= IDLE_THRESHOLD_MS) {
          const sleepMinutes = SLEEP_IF_IDLE_MS / 1000 / 60;
          console.log(`[newsMainWorker] 本輪只花 ${elapsedSec}s，判定為空閒狀態，sleep ${sleepMinutes} 分鐘...`);
          await sleep(SLEEP_IF_IDLE_MS);
        }
    }
}

// 啟動
mainLoop().catch(err => {
  console.error('[newsMainWorker] 無法啟動:', err);
  process.exit(1);
});

// 優雅關閉
process.on('SIGINT', () => {
    console.log('\n[newsMainWorker] 收到 SIGINT，準備結束');
    process.exit(0);
});

process.on('SIGTERM', () => {
    console.log('\n[newsMainWorker] 收到 SIGTERM，準備結束');
    process.exit(0);
});
