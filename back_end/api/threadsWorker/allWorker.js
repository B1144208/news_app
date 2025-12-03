// api/threadsWorker/newsAllWorker.js
'use strict';

const pool = require('../connect_db');
const { newsAllClassifier } = require('../middlewares/classifierController');
const { searchGroup } = require('../middlewares/groupController');
const { searchLocation } = require('../middlewares/locationController');
const { insertKeyword } = require('../middlewares/keywordController');
const { searchNews, insertNews } = require('../middlewares/newsController');
const { getText } = require('../middlewares/scriptController');
const { callAndCatchApiSuccessInGeneralFunction } = require('../utils/fakeHelper');

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * 抓出「任一 group/location/keyword 還沒做」的 news_id
 * 依照三個欄位加總分數由大到小，再依 created_at 越舊越前面
 */
async function fetchPendingNewsIds(LIMIT) {
  const sql = `
    SELECT
      nt.news_id
    FROM news_task AS nt
    JOIN news_data AS nd
      ON nd.news_id = nt.news_id
    ORDER BY
      nd.created_at DESC
    LIMIT ?;
  `;

  const [rows] = await pool.query(sql, [LIMIT]);
  return rows.map(r => r.news_id);
}

/* ---------- group：寫入 news_group ---------- */

async function insertNewsGroupsForOneNews(newsId, groupResult) {
  // 若回傳格式怪怪的，統一當成 []
  let namesToSearch = Array.isArray(groupResult) ? groupResult : [];

  if (namesToSearch.length === 0) {
    namesToSearch = ['其他'];
  }

  const insertSql = `
    INSERT IGNORE INTO news_group (news_id, group_data_id, group_detail_id)
    VALUES ?
  `;

  const rowsToInsert = []; // [[newsId, dataId, detailId], ...]

  for (const rawName of namesToSearch) {
    const groupName = (rawName || '').trim() || '其他';

    let searchGroupResult;
    try {
      const fakeReq = { query: { name: groupName } };
      searchGroupResult = await callAndCatchApiSuccessInGeneralFunction(
        searchGroup,
        fakeReq
      );
    } catch {
      continue;
    }

    if (!searchGroupResult || !searchGroupResult.type || !searchGroupResult.id) {
      continue;
    }

    const { type, id } = searchGroupResult;
    let dataId = null;
    let detailId = null;

    if (type === 'data') dataId = id;
    else if (type === 'detail') detailId = id;
    else continue;

    rowsToInsert.push([newsId, dataId, detailId]);
  }

  if (rowsToInsert.length === 0) return true;

  try {
    await pool.query(insertSql, [rowsToInsert]);
    return true;
  } catch (err) {
    console.warn('[newsAllWorker] 寫入 news_group 失敗，news_id =', newsId, 'err =', err.message);
    return false;
  }
}

/* ---------- location：寫入 news_location ---------- */

async function insertNewsLocationsForOneNews(newsId, locationResult) {
  let names = Array.isArray(locationResult) ? locationResult : [];

  names = [...new Set(
    names
      .filter(v => typeof v === 'string')
      .map(v => v.trim())
      .filter(Boolean)
  )];

  if (names.length === 0) return true;

  const insertSql = `
    INSERT IGNORE INTO news_location (
      news_id,
      location_region_id,
      location_country_id,
      location_state_id
    )
    VALUES ?
  `;

  const rowsToInsert = []; // [[newsId, regionId, countryId, stateId], ...]

  for (const locationName of names) {
    let searchLocationResult;
    try {
      const fakeReq = { query: { name: locationName } };
      searchLocationResult = await callAndCatchApiSuccessInGeneralFunction(
        searchLocation,
        fakeReq
      );
    } catch {
      continue;
    }

    if (!searchLocationResult || !searchLocationResult.type || !searchLocationResult.id) {
      continue;
    }

    const { type, id } = searchLocationResult;
    let regionId = null;
    let countryId = null;
    let stateId = null;

    if (type === 'region') regionId = id;
    else if (type === 'country') countryId = id;
    else if (type === 'state') stateId = id;
    else continue;

    rowsToInsert.push([newsId, regionId, countryId, stateId]);
  }

  if (rowsToInsert.length === 0) return true;

  try {
    await pool.query(insertSql, [rowsToInsert]);
    return true;
  } catch (err) {
    console.warn('[newsAllWorker] 寫入 news_location 失敗，news_id =', newsId, 'err =', err.message);
    return false;
  }
}

/* ---------- keyword：寫入 relation_keyword ---------- */

async function insertNewsKeywordsForOneNews(newsId, keywords) {
  if (!Array.isArray(keywords) || keywords.length === 0) return true;

  let namesToInsert = keywords
    .filter(k => typeof k === 'string')
    .map(k => k.trim())
    .filter(Boolean);

  if (namesToInsert.length === 0) return true;

  namesToInsert = [...new Set(namesToInsert)];

  // 查 relation_id
  const relationSql = `
    SELECT relation_id
    FROM news_data
    WHERE news_id = ?
  `;
  let relationId;
  try {
    const [rows] = await pool.query(relationSql, [newsId]);
    relationId = rows[0]?.relation_id;
    if (!relationId) return true; // 找不到就算了
  } catch (err) {
    console.error('[newsAllWorker] relation_id 查詢錯誤，news_id =', newsId, 'err =', err.message);
    return false;
  }

  const rowsToInsert = [];

  for (const keyword of namesToInsert) {
    let insertKeywordResult;
    try {
      const fakeReq = { body: { text: keyword } };
      insertKeywordResult = await callAndCatchApiSuccessInGeneralFunction(
        insertKeyword,
        fakeReq
      );
    } catch {
      continue;
    }

    const keywordId = insertKeywordResult?.insertId;
    if (!keywordId) continue;

    rowsToInsert.push([relationId, keywordId]);
  }

  if (rowsToInsert.length === 0) return true;

  const insertSql = `
    INSERT IGNORE INTO relation_keyword (relation_id, keyword_id)
    VALUES ?
  `;

  try {
    await pool.query(insertSql, [rowsToInsert]);
    return true;
  } catch (err) {
    console.warn('[newsAllWorker] 寫入 relation_keyword 失敗，relation_id =', relationId, 'err =', err.message);
    return false;
  }
}

/* ---------- reporter：更新 news_data.reporter_script ---------- */

async function updateNewsReporterForOneNews(newsId, reporterText) {
  if (typeof reporterText !== 'string') return true;

  const text = reporterText.trim();
  if (!text) return true; // 空字串就當作沒東西，不當錯誤

  const sql = `
    UPDATE news_data
    SET reporter_script = ?
    WHERE news_id = ?;
  `;
  try {
    await pool.query(sql, [text, newsId]);
    return true;
  } catch (err) {
    console.warn('[newsAllWorker] 更新 reporter_script 失敗，news_id =', newsId, 'err =', err.message);
    return false;
  }
}

/* ---------- chat：寫入 news_chat (news_id, chat_speaker, chat_text, chat_order) ---------- */

async function insertNewsChatForOneNews(newsId, chatList) {
  if (!Array.isArray(chatList) || chatList.length === 0) return true;

  // 先刪掉舊的（確保重新跑時不會重複）
  try {
    await pool.query('DELETE FROM news_chat WHERE news_id = ?', [newsId]);
  } catch (err) {
    console.warn('[newsAllWorker] 刪除舊 chat 失敗，news_id =', newsId, 'err =', err.message);
    // 刪不掉就不要再插入，避免狀態亂掉
    return false;
  }

  const rowsToInsert = [];

  chatList.forEach((item, idx) => {
    if (!item || typeof item.text !== 'string') return;

    const text = item.text.trim();
    if (!text) return;

    // speaker 只接受 A / B，預設錯的就當 A
    const speaker = item.speaker === 'B' ? 'B' : 'A';
    const order = idx + 1;

    rowsToInsert.push([newsId, speaker, text, order]);
  });

  if (rowsToInsert.length === 0) return true;

  const insertSql = `
    INSERT INTO news_chat (news_id, chat_speaker, chat_text, chat_order)
    VALUES ?;
  `;

  try {
    await pool.query(insertSql, [rowsToInsert]);
    return true;
  } catch (err) {
    console.warn('[newsAllWorker] 寫入 news_chat 失敗，news_id =', newsId, 'err =', err.message);
    return false;
  }
}

/* ---------- translate：翻譯 非中文新聞 ---------- */

async function insertNewsTranslateForOneNews(originalNewsId, translate) {
  // --------- 情況一：沒有 translate（本來就中文）---------
  if (!translate) {

    try {
      await pool.query(
        'UPDATE news_data SET is_chinese = 1 WHERE news_id = ?;',
        [originalNewsId]
      );
    } catch (err) {
      console.warn(
        '[newsAllWorker] insertNewsTranslateForOneNews: 更新原新聞 is_chinese 失敗，news_id =',
        originalNewsId,
        'err =',
        err.message
      );
    }

    // 沒有新新聞，後面就直接對原 newsId 寫 group/location/keyword...
    return { targetNewsId: originalNewsId, newNewsId: null };
  }

  // --------- 情況二：有 translate，要產生一筆新的「中文新聞」---------
  try {
    // 1) 取原始新聞完整資料
    const fakeReqForSearch = {
      query: { mode: 'complex' },
      body: { id: originalNewsId }
    };

    const searchRes = await callAndCatchApiSuccessInGeneralFunction(
      searchNews,
      fakeReqForSearch
    );

    const original = searchRes?.complexList?.[0];
    if (!original) {
      console.warn('[newsAllWorker] insertNewsTranslateForOneNews: searchNews 找不到對應新聞，news_id =', originalNewsId);
      return { targetNewsId: originalNewsId, newNewsId: null };
    }

    const iso = String(original.publishDate); 
    const d = new Date(iso);
    const pad2 = (n) => String(n).padStart(2, '0');
    const publishDate =
    `${d.getFullYear()}/` +
    `${pad2(d.getMonth() + 1)}/` +
    `${pad2(d.getDate())} ` +
    `${pad2(d.getHours())}:` +
    `${pad2(d.getMinutes())}:` +
    `${pad2(d.getSeconds())}`;

    // 2) 組成新的中文新聞 payload
    const newNewsPayload = {
      url: '原網址: ' + (original.newsUrl || ''),
      channel: original.channelName || '',
      cover_img: {
        src: original.coverImageUrl || '',
        alt: null     // 你指定 alt = null
      },
      title: translate.title,       // 中文標題
      publish_date: publishDate,
      detail: translate.content     // 中文內文
    };

    const fakeReqForInsert = { body: newNewsPayload };
    const insertRes = await callAndCatchApiSuccessInGeneralFunction(insertNews, fakeReqForInsert);
    const newNewsId = insertRes?.insertId;
    console.log("insertId: ", newNewsId);
    if (!newNewsId) {
      console.warn('[newsAllWorker] insertNewsTranslateForOneNews: insertNews 沒有回傳 insertId，news_id =',originalNewsId);
      return { targetNewsId: originalNewsId, newNewsId: null };
    }

    // 3) 更新新新聞：is_chinese = 1, translate_id = 原本 newsId
    try {
      await pool.query(
        `
          UPDATE news_data
          SET relation_id = ?,
              is_chinese = 1,
              translate_id = ?
          WHERE news_id = ?;
        `,
        [original.relationId, originalNewsId, newNewsId]
      );
    } catch (err) {
      console.warn('[newsAllWorker] insertNewsTranslateForOneNews: 更新新新聞 is_chinese/translate_id 失敗，新 news_id =', newNewsId, 'err =', err.message);
    }

    // 後面 group/location/keyword... 都寫到 newNewsId 上
        return { targetNewsId: newNewsId, newNewsId };
    } catch (err) {
        console.warn('[newsAllWorker] insertNewsTranslateForOneNews: 流程發生錯誤，fallback 原新聞，news_id =', originalNewsId, 'err =', err.message);
        return { targetNewsId: originalNewsId, newNewsId: null };
    }
}

/* ---------- 將 news_task 三個欄位都設為完成 ---------- */

async function markTaskDoneAll(newsId) {
  const sql = `
    DELETE FROM news_task
    WHERE news_id = ?;
  `;
  await pool.query(sql, [newsId]);
}
/*async function markTaskDoneAll(newsId) {
  const sql = `
    UPDATE news_task
    SET news_group = 1
    WHERE news_id = ?;
  `;
  await pool.query(sql, [newsId]);
}*/

/* ---------- 處理單一 news 的完整流程 ---------- */

async function handleOneNews(newsItem) {
  const newsId  = newsItem.id;           // 原始（可能是英文） news_id
  const title   = newsItem.title || '';
  const newsText = newsItem.text  || '';

  const fakeReq = {
    body: { title, content: newsText },
  };

  try {
    const result = await callAndCatchApiSuccessInGeneralFunction(
      newsAllClassifier,
      fakeReq
    );
    //console.log('[newsAllWorker] classifier result:', result);

    if (!result) {
      console.warn(
        `[newsAllWorker] news_id=${newsId} newsAllClassifier 未正常完成，略過 markTaskDone`
      );
      return;
    }

    // 把 translate 也一起解構出來
    const { group, location, keyword, reporter, chat, translate } = result;

    // 先處理翻譯／is_chinese，拿到 targetNewsId & newNewsId
    const { targetNewsId, newNewsId } =
      await insertNewsTranslateForOneNews(newsId, translate);

    // 決定哪些 news_id 要寫入（舊 + 新）
    const idsToWrite = newNewsId ? [newsId, newNewsId] : [newsId];

    let ok = true;

    // 對每一個 id 都寫 group/location/keyword/reporter/chat
    for (const targetId of idsToWrite) {
      if (!(await insertNewsGroupsForOneNews(targetId, group)))      ok = false;
      if (!(await insertNewsLocationsForOneNews(targetId, location))) ok = false;
      if (!(await insertNewsKeywordsForOneNews(targetId, keyword)))  ok = false;
      if (!(await updateNewsReporterForOneNews(targetId, reporter))) ok = false;
      if (!(await insertNewsChatForOneNews(targetId, chat)))        ok = false;
    }

    if (!ok) {
      console.warn(
        `[newsAllWorker] news_id=${newsId} 有部分寫入失敗，暫不刪除 news_task`
      );
      return;
    }

    // ★ 任務完成：舊的、新的都 mark 一下
    await markTaskDoneAll(newsId);        // 原本那筆
    if (newNewsId) {
      await markTaskDoneAll(newNewsId);   // 新增的翻譯那筆
    }
  } catch (err) {
    err.desc =
      'threadsWorker-newsAll-handleOneNews(): ' + (err.message || '');
    console.error(err.desc);
  }
}

/* ---------- 主流程 ---------- */

async function runAllWorker(LIMIT = 100, idList = null) {
    console.log('[newsAllWorker] 啟動');
        
    try {
        if (!idList)
            idList = await fetchPendingNewsIds(LIMIT);

        console.log('[newsAllWorker] 抓取 idList =', idList);

        if (idList.length === 0) {
            console.log('[newsAllWorker] 目前沒有待處理的任務');
            return;
        }

        let newsTextList;
        try {
            const fakeReqForGetText = {
                query: { idList: idList, origin_body: '' },
            };

            newsTextList = await callAndCatchApiSuccessInGeneralFunction(
                getText,
                fakeReqForGetText
            );

            if (!Array.isArray(newsTextList)) {
                console.warn('[newsAllWorker] getText 回傳不是陣列，實際：', newsTextList);
                newsTextList = [];
            }
        } catch (err) {
            console.error('[newsAllWorker] 呼叫 getText 發生錯誤：', err);
            await sleep(30 * 1000);
            return;
        }

        for (const newsItem of newsTextList) {
            console.log(
                `=============== news_id = ${newsItem.id} ===============`
            );

            if (!newsItem || typeof newsItem.id === 'undefined') {
                console.warn('[newsAllWorker] newsItem 格式不正確，略過：', newsItem);
                continue;
            }

            try {
                await handleOneNews(newsItem);
            } catch (err) {
                console.error('[newsAllWorker] 處理 news_id =', newsItem.id, '時發生錯誤：', err);
            }
        }
    } catch (err) {
        console.error('[newsAllWorker] 主流程發生錯誤：', err);
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


module.exports = {
  runAllWorker,
};
