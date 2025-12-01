// threadsWorker/newsMainWorker.js
'use strict';

const pool = require('../connect_db');
const { runGroupWorker }    = require('./newsGroupWorker');
const { runLocationWorker } = require('./newsLocationWorker');
const { runKeywordWorker }  = require('./newsKeywordWorker');

const SLEEP_IF_IDLE_MS = 60 * 60 * 1000; // 1 小時
const IDLE_THRESHOLD_MS = 20 * 1000;     // 20 秒

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// 主迴圈
async function mainLoop() {
  console.log('[newsMainWorker] 啟動');

    while (true) {

        const loopStart = Date.now();

        // 1. ) newsGroup ( 100 筆 )
        try { await runGroupWorker(); } 
        catch (err) { console.warn('[newsMainWorker] group error, news_id =', err.message); }

        // 2. ) newsLocation ( 100 筆 )
        try { await runLocationWorker(); }
        catch (err) { console.warn('[newsMainWorker] location error, news_id =', err.message); }

        // 3. ) newsKeyword ( 100 筆 )
        try { await runKeywordWorker(); }
        catch (err) { console.warn('[newsMainWorker] keyword error, news_id =', err.message); }

        // 4. )
        // 5. )
        
        const loopEnd = Date.now();
        const elapsedMs = loopEnd - loopStart;
        const elapsedSec = (elapsedMs / 1000).toFixed(2);

        // 如果整圈跑完的時間「不超過 20 秒」，代表現在大概沒 backlog → 睡一小時
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