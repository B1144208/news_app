const pool = require('../connect_db');
const axios = require('axios');
const path = require('path');
const { checkRequireField } = require('../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');
const { shortenArticle, cleanNewsScript } = require('../utils/scriptHelper');
const { execFile } = require('child_process');
const { searchNews } = require('./newsController');
const { runAllWorker } = require('../threadsWorker/allWorker');
const { quickScriptModel } = require('../openai/quickScript');




const OLLAMA_URL = 'http://localhost:11434/api/generate';
const OLLAMA_MODEL = 'qwen2.5:1.5b';
const QUICK_SCRIPT_MODEL = 'quick-script'; // 快速播放專用 model

/*
@ general, reporter, chat: 給予一個 List {"id", "title", "text"}
@ general: 僅 news_body
@ reporter: 記者播報
@ chat: 聊天對白
@
*/

async function getText (req, res, next) {
    let { idList } = req.query ?? {}
    const origin_body = req.query?.origin_body !== undefined;

    fakeReq = {
      query: { mode: "complex" },
      body: { id: idList}
    }
    try {
      let result = await callAndCatchApiSuccess(searchNews, fakeReq);
      result = result.complexList.map(item => {
        if (origin_body) {
          return {
            id: item.newsId,
            title: item.newsTitle,
            text: item.newsBody
          };
        }
        const bodyText = (item.newsBody || [])
          .filter(part => typeof part.text === 'string' && part.text.trim() !== '')
          .map(part => part.text.trim())
          .join('\n');

        return {
          id: item.newsId,
          title: item.newsTitle,
          text: bodyText
        }
      });
      return res.apiSuccess(result, "Search Success");
    } catch (err) {
      err.desc = "middlewares-scriptController(): error";
      return next(err);
    }
}

/**
 * 從 news/text 結構中生出 blocks
 * 目前假設：
 * - news.text 是 [{text}, {img:{src,alt}}, ...]
 * - 或 news.content 是同樣格式
 * - 如果只是純字串 content，就包成 [{text: content}]
 */
function normalizeBlocksFromNews(news) {
  if (Array.isArray(news?.text)) return news.text;
  if (Array.isArray(news?.content)) return news.content;

  const s = (news?.content ?? '').toString().trim();
  if (!s) return [];
  return [{ text: s }];
}

/** 把 blocks 攤平成純文字（給 LLM 用） */
function flattenBlocksToPlainText(blocks) {
  if (!Array.isArray(blocks)) return '';
  return blocks
    .map(b => {
      if (!b || typeof b !== 'object') return '';
      if (typeof b.text === 'string') return b.text;
      if (b.img && typeof b.img.alt === 'string') return b.img.alt;
      return '';
    })
    .filter(Boolean)
    .join('\n');
}

/** 判斷字串是否「主要是中文」：中文字 >= 英文字母就算中文 */
function isMostlyChinese(str) {
  if (!str) return false;
  const han   = (str.match(/[\u4E00-\u9FFF]/g) || []).length;
  const latin = (str.match(/[A-Za-z]/g) || []).length;
  if (han === 0 && latin === 0) return false;
  return han >= latin;
}



/**
 * 從 DB 裡補上 reporter_script & news_chat
 * @param {number[]} idList
 * @param {Map<number, Object>} scriptById  // id -> {id,title,general,reporter,chat}
 */
async function loadReporterAndChatForIds(idList, scriptById) {
  if (!Array.isArray(idList) || !idList.length) return;

  const ph = idList.map(() => '?').join(',');
  const params = idList;

  // 1) reporter_script
  const sqlReporter = `
    SELECT news_id, reporter_script
    FROM news_data
    WHERE news_id IN (${ph})
      AND reporter_script IS NOT NULL
      AND reporter_script <> ''
  `;
  const [rowsReporter] = await pool.query(sqlReporter, params);

  for (const row of rowsReporter) {
    const entry = scriptById.get(row.news_id);
    if (entry && !entry.reporter) {
      entry.reporter = row.reporter_script;
    }
  }

  // 2) news_chat
  const sqlChat = `
    SELECT
      news_id,
      chat_speaker AS speaker,
      chat_text    AS text,
      chat_order
    FROM news_chat
    WHERE news_id IN (${ph})
    ORDER BY news_id, chat_order
  `;
  const [rowsChat] = await pool.query(sqlChat, params);

  const chatGrouped = new Map();
  for (const row of rowsChat) {
    if (!chatGrouped.has(row.news_id)) {
      chatGrouped.set(row.news_id, []);
    }
    chatGrouped.get(row.news_id).push({
      speaker: row.speaker,
      text: row.text
    });
  }

  for (const [newsId, chatArr] of chatGrouped) {
    const entry = scriptById.get(newsId);
    if (entry && (!entry.chat || !entry.chat.length)) {
      entry.chat = chatArr;
    }
  }
}

/**
 * SSE：一個一個把 {id,title,general,reporter,chat} 丟給前端
 * 流程：
 * 1. 從 body 取 idList
 * 2. 用 getText 拿 {id,title,general}
 * 3. 查 DB 拿 reporter_script & news_chat，組成 scriptMap
 * 4. 沒有 reporter/chat 的再組一個 pendingIds 丟給 runAllWorker(idList)
 * 5. 從 scriptMap 第一筆開始找「已經完整」的，遇到缺的就停，每 3 秒重查 DB
 * 6. 一旦某筆補齊就立刻 res.write 丟出去
 */
async function getScript(req, res, next) {
  try {
    // 1) 取得 idList
    let idList = req.query?.idList;

    if (typeof idList === 'string') {
    try {
        idList = JSON.parse(idList);   // 變成真正的陣列
      } catch (e) {
        // parse 失敗再看情況處理
      }
    }

    if (!Array.isArray(idList) || !idList.length) {
      return res.status(400).json({
        ok: false,
        error: 'idList is required and must be a non-empty array'
      });
    }

    // 整理成整數 & 去重
    idList = Array.from(
      new Set(
        idList
          .map(x => Number(x))
          .filter(x => Number.isInteger(x) && x > 0)
      )
    );

    if (!idList.length) {
      return res.status(400).json({
        ok: false,
        error: 'idList is empty after normalization'
      });
    }

    // 2) getText 取得基本 script（假設回傳 [{id,title,general}, ...]）
    let baseList;
    try {
      // ⚠️ 依你實際的 getText 介面調整：
      //   如果是 getText(idList) 就這樣；如果是 getText({idList}) 就改。
      fakeReq = {
        query: {idList}
      }
      baseList = await callAndCatchApiSuccess(getText, fakeReq);
    } catch (err) {
      err.desc = 'getText() failed in getScript';
      throw err;
    }

    // 建立 scriptMap & map 索引：保持 idList 的順序
    const scriptMap = [];
    const scriptById = new Map();

    for (const id of idList) {
      const base = Array.isArray(baseList)
        ? baseList.find(x => Number(x.id) === id)
        : null;

      const entry = {
        id,
        title: base?.title || '',
        general: base?.general || '',
        reporter: null,
        chat: null
      };

      scriptMap.push(entry);
      scriptById.set(id, entry);
    }

    // 3) 先查一次 DB，補上已經有的 reporter_script / news_chat
    await loadReporterAndChatForIds(idList, scriptById);

    // 4) 找出還缺 reporter 或 chat 的 idList
    const pendingIds = scriptMap
      .filter(it => !it.reporter || !it.chat || !it.chat.length)
      .map(it => it.id);

    // 5) 把 pendingIds 丟給 runAllWorker（背景慢慢跑，負責寫 DB）
    if (pendingIds.length) {
      // 不 await，讓它在背景跑
      runAllWorker(0, pendingIds).catch(err => {
        console.error('runAllWorker error in getScript:', err);
      });
    }

    // ========= 設定 SSE / chunked response =========
    res.setHeader('Content-Type', 'text/event-stream; charset=utf-8');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    if (res.flushHeaders) res.flushHeaders();

    let currentIndex = 0;
    let timer = null;
    let ended = false;

    function sendItem(entry) {
      const payload = {
        type: 'item',
        newsId: entry.id,
        title: entry.title,
        general: entry.general,
        reporter: entry.reporter,
        chat: entry.chat
      };
      res.write(`data: ${JSON.stringify(payload)}\n\n`);
    }

    function sendDone() {
      if (ended) return;
      ended = true;
      res.write(`data: ${JSON.stringify({ type: 'done' })}\n\n`);
      res.end();
      if (timer) clearInterval(timer);
    }

    // 檢查 scriptMap[currentIndex..]，把「連續 ready 的」通通丟出去
    async function tryFlushReady() {
      while (currentIndex < scriptMap.length) {
        const item = scriptMap[currentIndex];
        const ready =
          item &&
          item.reporter &&
          item.reporter.toString().trim() &&
          Array.isArray(item.chat) &&
          item.chat.length > 0;

        if (!ready) break;

        sendItem(item);
        currentIndex++;
      }

      if (currentIndex >= scriptMap.length) {
        // 全部送完
        sendDone();
        return true;
      }
      return false;
    }

    // 先試著 flush 一次（有些可能一開始就已經有 script 了）
    const finishedInitially = await tryFlushReady();
    if (finishedInitially) {
      return;
    }

    // 6) 每 3 秒重查 DB：只查還沒 ready、而且 index 之後的那幾筆
    timer = setInterval(async () => {
      if (ended || res.writableEnded) {
        clearInterval(timer);
        return;
      }

      // 還沒送出的 & 不完整的 idList
      const needIds = scriptMap
        .slice(currentIndex)
        .filter(
          it =>
            !it.reporter ||
            !it.reporter.toString().trim() ||
            !Array.isArray(it.chat) ||
            !it.chat.length
        )
        .map(it => it.id);

      if (!needIds.length) {
        // 可能只是前面還沒 flush 完，試一次
        const done = await tryFlushReady();
        if (done) return;
        return;
      }

      // 再從 DB 補一次資料
      try {
        await loadReporterAndChatForIds(needIds, scriptById);
      } catch (err) {
        console.error('loadReporterAndChatForIds in timer error:', err);
        // 這裡先不直接結束，下一輪再試
      }

      // 補完後再試著 flush
      const done = await tryFlushReady();
      if (done) return;
    }, 3000);

    // 如果前端關掉連線（例如按「中止」），就停止 timer
    req.on('close', () => {
      if (!ended) {
        console.log('client closed getScript connection');
        if (timer) clearInterval(timer);
        ended = true;
      }
    });
  } catch (err) {
    console.error('getScript fatal error:', err);
    if (!res.headersSent) {
      return next(err);
    }
    // headers 已送出就只能結束連線
    try {
      res.end();
    } catch (_) {}
  }
}

async function getQuickScipt(req, res, next) {

  // searchNews 抓 10 筆資料
  /*let fakeReq = {
    query: { mode: "id", limit: 10},  //, order: "heat"
    body: {}
  }
  try {
    let result = await callAndCatchApiSuccess(searchNews, fakeReq);
    console.log("result: ", result);
    let 
  } catch (err) {
    err.desc = "middlewares-scriptController(): searchNews error";
    return next(err);
  }*/
  news =
        [
            {
              "url": "https://www.ettoday.net/news/20251203/3077535.htm",
              "group": "國際",
              "channel": "ETtoday新聞雲",
              "cover_img": {
                "src": "//cdn2.ettoday.net/images/8489/8489660.jpg",
                "alt": "▲美國總統川普正式簽字。（示意圖非本次事件畫面／達志影像／美聯社）"
              },
              "title": "快訊／川普簽字！　白宮：《台灣保證實施法案》正式生效",
              "publish_date": "2025/12/03 00:00",
              "detail": [
                {
                  "text": "白宮2日宣布，美國總統川普已正式簽署「台灣保證實施法案」，要求美國國務院定期強制審查美國對台交往準則，並提出移除限制的計畫，被視為深化美台關係的最新立法進展。"
                },
                {
                  "text": "「台灣保證實施法案」今年5月在眾議院過關，11月18日於參議院無異議通過後送交川普簽署生效。法案規定，國務院至少每5年必須全面檢視與台灣互動的規範，並研擬逐步解除限制美台官方往來的方案。"
                },
                {
                  "text": "法案由共和黨眾議員華格納（Ann Wagner）、已故民主黨眾議員康諾里（Gerry Connolly）及民主黨眾議員劉雲平（Ted Lieu）在2月共同提出。華格納強調，立法展現美國國會跨黨派反對中國共產黨區域擴權的立場，也重申對台承諾。"
                },
                {
                  "text": "自1979年美國與中華民國斷交後，國務院透過內部文件規範外交與軍事官員與台灣接觸的各項「紅線」，包含訪問層級、場合與公開活動等。法案核心精神即在打破這些歷史性限制，使美台官方往來逐步正常化。"
                },
                {
                  "text": "2021年1月，時任國務卿龐培歐（Mike Pompeo）曾宣布取消所有對台交往準則；但拜登政府上任後恢復準則體系，同時放寬部分限制，例如允許台灣官員進入聯邦機構會晤，美方官員也可頻繁前往駐美代表處交流。"
                }
              ],
              "keyword": [
                "川普",
                "台灣",
                "北美要聞",
                "台灣保證實施法案",
                "簽字",
                "生效",
                "國務院",
                "交往準則"
              ],
              "comment": null
            },
            {
              "url": "https://udn.com/news/story/124658/9179084",
              "group": "國際",
              "channel": "聯合新聞網",
              "cover_img": {
                "src": "https://uc.udn.com.tw/photo/2025/12/03/realtime/33859141.jpg",
                "alt": "日本首相高市早苗11月25日與美國總統川普通電話後，在東京官邸受訪。路透"
              },
              "title": "1972年日中聯合聲明「台灣是中國領土不可分割的一部分」 高市：沒有改變",
              "publish_date": "2025/12/03 12:42:12",
              "detail": [
                {
                  "text": "日本首相高市早苗在3日的參議院全體會議上表示，對於中國大陸在1972年《日中聯合聲明》中宣示「台灣是中華人民共和國領土不可分割的一部分」，而日本採取「理解並尊重」這一立場一事，「絲毫沒有改變」。"
                },
                {
                  "text": "每日新聞報導，公明黨參議員竹內真二指出高市日前的「台灣有事」相關答辯言論可能帶來的影響，並表示：「我國必須以冷靜且一貫的立場應對，防止事態進一步升級。」隨後他詢問高市，政府在台灣相關問題上的立場是否仍與《日中聯合聲明》一致。"
                }
              ],
              "keyword": [
                "高市早苗",
                "台灣有事",
                "日中聯合聲明",
                "參議院",
                "日本首相"
              ],
              "comment": null
            },
            {
              "url": "https://s.yimg.com/ny/api/res/1.2/jwxNcDmCVxeuHSPp.3FfGg--/YXBwaWQ9aGlnaGxhbmRlcjt3PTk2MDtoPTY4MDtjZj13ZWJw/https://media.zenfs.com/zh-tw/bcc.com.tw/2a7b8cf6fb30bbe32f5abd6cac5c95bf",
              "group": "國際",
              "channel": "Yahoo奇摩新聞",
              "cover_img": {
                "src": "https://s.yimg.com/ny/api/res/1.2/jwxNcDmCVxeuHSPp.3FfGg--/YXBwaWQ9aGlnaGxhbmRlcjt3PTk2MDtoPTY4MDtjZj13ZWJw/https://media.zenfs.com/zh-tw/bcc.com.tw/2a7b8cf6fb30bbe32f5abd6cac5c95bf",
                "alt": "日本首相高市早苗，3日在日本參議院答詢時表示，對於《日中共同聲明》中所載，台灣是中華人民共和國一部分的說法，日本政府充分理解，也完全尊重。"
              },
              "title": "高市早苗縮了！ 稱「台灣是中國領土不可分割的一部分」",
              "publish_date": "2025/12/03 00:00",
              "detail": [
                {
                  "text": "日本首相高市早苗，今（3）日在日本參議院答詢時公開表明，日本對於1972年《日中共同聲明》宣示的「台灣是中華人民共和國不可分割的一部分」，理解並且尊重，立場沒有任何改變。（葉柏毅報導）"
                },
                {
                  "text": "綜合日本媒體報導，公明黨籍參議員竹內真二，3日在質詢高市早苗時表示，高市早苗先前所說的「台灣有事論」，使中日關係持續緊繃。他呼籲高市，在台海議題上，必須要以冷靜且一貫的立場因應，以防止事態進一步升級。隨後竹內真二詢問高市，到底是怎麼看待台灣與中國大陸的關係？"
                },
                {
                  "text": "報導說，高市在回答竹內真二的質詢時，清楚表示，日本政府在台灣相關問題上的基本立場，一如1972年《日中共同聲明》所載，「台灣是中華人民共和國領土不可分割的一部分」，這一立場「絲毫沒有改變」。"
                },
                {
                  "text": "高市早苗11月7日，在眾議院答詢時表示，如果中國大陸侵略台灣，即所謂的「台灣有事」，這可能會造成日本的「存亡危機事態」，而讓日本必須行使「集體自衛權」，這是日本現任首相首次針對「台灣有事即日本有事」，做出明確表態，也引發中日外交關係大波瀾。如今，高市重新強調「台灣是中華人民共和國一部分」，也等於是希望為掀波的「台灣有事論」，就此畫下句點。"
                }
              ],
              "keyword": [
                "高市早苗",
                "台灣是中國領土不可分割的一部分",
                "日中共同聲明",
                "參議院",
                "台灣有事論",
                "中華人民共和國",
                "集體自衛權"
              ],
              "comment": null
            },
            {
              "url": "https://tw.news.yahoo.com/trump-signs-taiwan-assurance-implementation-act-000000021.html",
              "group": "國際",
              "channel": "Yahoo奇摩新聞",
              "cover_img": {
                "src": "https://s.yimg.com/ny/api/res/1.2/5yH1KeiDd1p05lsp7SV1Kw--/YXBwaWQ9aGlnaGxhbmRlcjt3PTk2MDtoPTUwMjtjZj13ZWJw/https://media.zenfs.com/ko/ebc.net.tw/c4d5878e04f85c9b2eff896bf8baec0a",
                "alt": "美國總統川普。（圖／美聯社）"
              },
              "title": "川普簽的「台灣保證實施法案」是什麼？7大重點一次看",
              "publish_date": "2025/12/03 00:00",
              "detail": [
                {
                  "text": "美國國會通過《台灣保證實施法案》（Taiwan Assurance Implementation Act），進一步強化美方對台政策的透明度與穩定性，白宮在2日也證實，總統川普已經簽署這項法案，法案核心是要求國務院定期檢視並更新與台灣往來的相關指引，讓美台關係不再因文書過時或行政部門的限制而受到影響。《EBC東森新聞》為您整理相關懶人包重點一次搞懂。"
                },
                {
                  "text": "一、什麼是《台灣保證實施法案》？"
                },
                {
                  "text": "美國在 2025 年通過並由川普總統簽署的《台灣保證實施法案》，是對 2020 年《台灣保證法》的制度化強化。新法要求國務院每五年定期檢討對台交往準則，並提出解除不必要、過時限制的具體方案，使美台互動從行政內規轉為法律化、可預期的制度，象徵美國正邁向讓雙方往來「正常化」的重要一步。"
                },
                {
                  "text": "二、最大亮點：從一次性改為「定期審查」"
                },
                {
                  "text": "1、國務院至少每5年進行一次審查與台灣往來的指引"
                },
                {
                  "text": "2、檢討後90天內須向國會提交更新報告"
                },
                {
                  "text": "3、重新發布最新指引給美國行政部門"
                },
                {
                  "text": "三、美國國會要求報告內容有哪些？"
                },
                {
                  "text": "指引是否充分反映國會的立場，例如認定台灣是透過自由、公平選舉產生的民選政府等重要原則，以及說明美方如何尋找機會解除美國對台灣自我設下的交往限制，例如官員互動、訪問層級等，並提出「解除這些不必要、過時限制」的具體方案。"
                },
                {
                  "text": "四、提案人是誰？"
                },
                {
                  "text": "主提案人：共和黨眾議員魏格納（Ann Wagner）；原始共同提案人：民主黨眾議員康諾里（Gerry Connolly）、民主黨眾議員劉雲平（Ted Lieu）。"
                },
                {
                  "text": "五、2025年法案立法時程"
                },
                {
                  "text": "眾議院於2/21提出，5/5無異議通過；參議院於11/18一致同意通過；11/21送交美國總統川普；川普於12/2簽署法案。"
                },
                {
                  "text": "六、台灣方面如何回應？"
                },
                {
                  "text": "外交部長林佳龍：表示誠摯歡迎與感謝，強調法案生效象徵台美關係再進一步，也是雙方關係正常化的進一步發展，將持續秉持互信、互惠、互利的原則，與美方保持密切溝通。"
                },
                {
                  "text": "總統府發言人郭雅慧：表達誠摯歡迎與感謝，認為這項法案的通過生效，肯定美國與台灣交往的價值，支持更緊密的臺美關係，是奠基於民主、自由、人權等共同價值的堅實象徵。"
                },
                {
                  "text": "七、中國方面如何回應？"
                },
                {
                  "text": "大陸國台辦港澳局長、新聞發言人張晗：回應美方所謂法案「粗暴干涉中國內政、嚴重違反一個中國原則和中美三個聯合公報規定的精神」，對此表示強烈的不滿和堅決的反對，敦促美方不與台灣地區進行任何形式的官方接觸。"
                }
              ],
              "keyword": [
                "川普",
                "台灣保證實施法案",
                "Taiwan Assurance Implementation Act",
                "國務院",
                "交往準則",
                "定期審查",
                "美台關係"
              ],
              "comment": null
            },
            {
              "url": "https://tw.news.yahoo.com/tag/王世堅",
              "group": "政治",
              "channel": "NOWnews今日新聞",
              "cover_img": {
                "src": "https://s.yimg.com/ny/api/res/1.2/_RuRuDg6V4U9aLPcRs9PPA--/YXBwaWQ9aGlnaGxhbmRlcjt3PTk2MDtoPTY0MjtjZj13ZWJw/https://media.zenfs.com/ko/nownews.com/90ef741765ac522c29f855b731010f24",
                "alt": "▲民進黨立委王世堅作為台北市長熱門人選，今（2）日首度談及不參選原因。（圖／匯流新聞網《中午來開匯》提供，2025.12.02）"
              },
              "title": "不選台北市長！王世堅首曝原因超心酸",
              "publish_date": "2025/12/02 00:00",
              "detail": [
                {
                  "text": "民進黨立委王世堅今（2）日接受政論直播節目《中午來開匯》專訪，作為台北市長熱門人選，他首度談及不參選原因，直言因自己是228與白色恐怖受難者後代，若輸給蔣家的下一代，他將無法面對自己和祖先。"
                },
                {
                  "text": "王世堅強調，自己「完全不可能」參選台北市長，並強調民進黨人才眾多，一定會推出最強人選迎戰。"
                },
                {
                  "text": "談及個人不考慮參選的深層原因，王世堅提到自己的家庭背景，指出自己是228事件與白色恐怖受難家屬，如果輸給蔣家的下一代，他覺得「無法面對自己、父親與祖父，也對不起所有228與白色恐怖受難者家屬」。"
                },
                {
                  "text": "他直言，這樣的心理因素也是他不願參選台北市長的重要理由之一，他強調，民進黨會推出最適合的候選人，他本人則不會投入這場選戰。"
                }
              ],
              "keyword": [
                "王世堅",
                "台北市長",
                "228事件",
                "白色恐怖",
                "受難者後代",
                "民進黨"
              ],
              "comment": null
            },
            {
              "url": "https://tw.news.yahoo.com/china-bully-japan-wsj-editorial-000000021.html",
              "group": "國際",
              "channel": "Yahoo奇摩新聞",
              "cover_img": {
                "src": "https://s.yimg.com/ny/api/res/1.2/TWKdmOVk5xKtMJBHICxfCw--/YXBwaWQ9aGlnaGxhbmRlcjt3PTk2MDtoPTY5MjtjZj13ZWJw/https://media.zenfs.com/zh-tw/bcc.com.tw/d4751e9136e81e264de83f097da99cbc",
                "alt": "美國華爾街日報發表社論，指中國大陸公然霸凌日本，是國際社會的一個「惡兆」。"
              },
              "title": "中國霸凌日本！ 華爾街日報社論：給全世界上了一課",
              "publish_date": "2025/12/01 00:00",
              "detail": [
                {
                  "text": "美國華爾街日報12月1日以「中國霸凌日本，給世界上了一課」為題，發表社論指出，在日本首相高市早苗說出「台灣有事論」之後，北京舖天蓋地的威逼恐嚇，對國際社會來說，是一項「惡兆」。社論直指，中國大陸不斷加劇對台威脅，才是真正的危險。（葉柏毅報導）"
                },
                {
                  "text": "日本首相高市早苗，11月7日在國會答詢時，拋出「台灣有事論」，引發中國大陸強烈不滿，而頻頻出招，除了出動無人機與海警船進行武力恐嚇之外，施壓力道也升高到經濟制裁，包括呼籲民眾暫赴日本旅遊，並以食安理由再度禁止日本水產進口。"
                },
                {
                  "text": "這篇社論也引述華爾街日報稍早報導指出，大陸國家主席習近平11月24日與川普通話，「有一半時間都是在抱怨對日本與台灣的各種不滿」；更令人憂心的是，報導稱川普隨後竟然致電高市早苗，要求不要在台灣問題上刺激北京。"
                },
                {
                  "text": "社論指出，沒人希望在台灣問題上挑起衝突，但究竟誰才是挑釁的一方？是說明如何回應侵略的領導人，還是規畫、備戰並威脅侵略的一方？社論也強調，美國總統川普如果真的有心要嚇阻北京進占台灣的野心，仍然必須要有日本相助。"
                }
              ],
              "keyword": [
                "中國霸凌",
                "華爾街日報",
                "社論",
                "日本",
                "高市早苗",
                "台灣有事論",
                "北京",
                "川普",
                "習近平",
                "台灣"
              ],
              "comment": null
            },
            {
          "url": "https://tw.news.yahoo.com/%E9%9B%A2%E8%AD%9C-%E5%8D%B0%E8%88%AA%E6%B3%A2%E9%9F%B3737%E5%AE%A2%E6%A9%9F%E6%B6%88%E5%A4%B113%E5%B9%B4-%E5%81%9C%E5%9C%A8%E6%A9%9F%E5%A0%B4%E7%AB%9F%E7%84%A1%E4%BA%BA%E7%9F%A5-%E9%82%84%E5%BE%97%E5%86%8D%E8%B3%A03500%E8%90%AC-011700021.html",
          "channel": "三立新聞網",
          "cover_img": {
            "src": "https://s.yimg.com/ny/api/res/1.2/khs9LzWUh1GatwLJw_DoVg--/YXBwaWQ9aGlnaGxhbmRlcjt3PTk2MDtoPTY1MDtjZj13ZWJw/https://media.zenfs.com/zh-tw/setn.com.tw/64911b85c0cde2630c995c781b388cab",
            "alt": "VT-EHH客機就這樣暴露於停機坪旁的空地，沒有屋頂遮蔽，也沒有任何機務管理。整架班機歷經日曬風吹雨打，機體已經斑駁。(圖/翻攝X平台 Fahad Naim)"
          },
          "title": "離譜！印航波音737客機消失13年 停在機場竟無人知 還得再賠3500萬",
          "publish_date": "2025-12-03",
          "detail": [
            {
              "img": {
                "src": "https://s.yimg.com/ny/api/res/1.2/khs9LzWUh1GatwLJw_DoVg--/YXBwaWQ9aGlnaGxhbmRlcjt3PTk2MDtoPTY1MDtjZj13ZWJw/https://media.zenfs.com/zh-tw/setn.com.tw/64911b85c0cde2630c995c781b388cab",
                "alt": "VT-EHH客機就這樣暴露於停機坪旁的空地，沒有屋頂遮蔽，也沒有任何機務管理。整架班機歷經日曬風吹雨打，機體已經斑駁。(圖/翻攝X平台 Fahad Naim)"
              }
            },
            {
              "text": "印度航空（Air India）近日爆出一起匪夷所思的離奇案件！一架從官方紀錄中「失蹤」13年的波音737客機，後來被發現竟然就在「眼前」，該失蹤飛機一直停在加爾各答機場（Kolkata Airport）角落，沒人發現，引發外界譁然。"
            },
            {
              "text": "據外媒報導，這架編號 VT-EHH 的 Boeing 737-2A8F，機齡已達43年。該機於1982年交付給「印度人航空」（Indian Airlines），2007年改裝為貨機，同年隨著印度人航空與印度航空合併，被納入印航機隊。2012年，這架老舊貨機停飛後長期停放於加爾各答機場，隔年正式註銷。然而，此後它竟從印航資產紀錄中完全消失，不僅未被列入折舊、保險或報廢流程，也未被納入任何維修清冊。"
            },
            {
              "text": "在接下來的13年中，VT-EHH就這樣暴露於停機坪旁的空地，沒有屋頂遮蔽，也沒有任何機務管理。整架班機歷經日曬風吹雨打，機體已經斑駁，直到加爾各答機場近期要求印航處理這架佔用場地多年的「廢機」，印航高層才驚覺仍擁有這架飛機。"
            },
            {
              "text": "印航執行長坎貝爾．威爾森（Campbell Wilson）在內部信件中坦承「這架飛機早就應該被處理，但令人震驚的是，我們居然沒有人知道它還在我們名下。」後續調查顯示，包括資產帳冊、折舊紀錄、保險及維修資料，全都未將這架飛機納入，暴露航空公司資產管理存在重大漏洞。"
            },
            {
              "text": "更令印航頭痛的是，該公司必須為長期占用停機坪支付超過1億印度盧比（約新台幣3490萬元）的停放費用。據了解，VT-EHH已於上月被出售並移至班加羅爾（Bengaluru），未來將作為航空維修技師訓練用途。"
            }
          ],
          "comment": []
        },
        {
          "url": "https://tw.news.yahoo.com/%E9%80%99%E8%A8%98%E6%86%B6%E9%AB%94%E7%9B%AE%E6%A8%99%E5%83%B9%E4%B8%8A%E7%9C%8B180%E5%85%83-eps%E4%B8%8A%E7%9C%8B19-5%E5%85%83-%E5%A0%B1%E5%83%B9-%E8%B7%AF%E9%A3%86%E5%88%B0%E6%98%8E%E5%B9%B4-234500712.html",
          "channel": "FTNN新聞網",
          "cover_img": {
            "src": "https://s.yimg.com/ny/api/res/1.2/Xxx0wQfy3i9RaejHuogT1w--/YXBwaWQ9aGlnaGxhbmRlcjt3PTk2MDtoPTU0MDtjZj13ZWJw/https://media.zenfs.com/ko/ftnn_com_tw_939/7f992fc943dbdc67adde1327afe668a5",
            "alt": "記憶體族群股價沉潛多時，卻在基本面火力全開的支撐下，再次被外資與投顧推上風口。（示意圖／pexels）"
          },
          "title": "這記憶體目標價上看180元！「EPS上看19.5元」報價一路飆到明年 華邦電、南亞科、群聯被點名「最猛3巨頭」",
          "publish_date": "2025-12-03",
          "detail": [
            {
              "text": "[FTNN新聞網]記者莊蕙如／綜合報導"
            },
            {
              "img": {
                "src": "https://s.yimg.com/ny/api/res/1.2/Xxx0wQfy3i9RaejHuogT1w--/YXBwaWQ9aGlnaGxhbmRlcjt3PTk2MDtoPTU0MDtjZj13ZWJw/https://media.zenfs.com/ko/ftnn_com_tw_939/7f992fc943dbdc67adde1327afe668a5",
                "alt": "記憶體族群股價沉潛多時，卻在基本面火力全開的支撐下，再次被外資與投顧推上風口。（示意圖／pexels）"
              }
            },
            {
              "text": "記憶體族群股價沉潛多時，卻在基本面火力全開的支撐下，再次被外資與投顧推上風口。研究機構最新預測顯示，DRAM與NAND的供需失衡將不是短線行情，而是一路延伸到2026年下半年，意味著記憶體報價將維持「長多格局」。在這波大循環下，法人再度圈選三檔核心指標：華邦電（2344）、南亞科（2408）、群聯（8299），直指它們將領軍下一輪記憶體大行情。"
            },
            {
              "text": "這波上升循環與過往短期補庫存動能不同，更類似智慧手機爆量、雲端伺服器大擴建與疫情期間WFH需求狂增的長周期模式。研究機構指出，推升報價一路走強的關鍵包括CSP伺服器訂單超乎預期，使其他應用被動遭排擠；HBM需求旺盛，位元產出被大量吃掉；AI伺服器的BOM成本吸震能力高，使需求幾乎未受擾動；加上原廠聚焦製程升級，產能擴張有限，讓供給端始終緊繃。"
            },
            {
              "text": "DDR4供需也因為產能調整而更加吃緊。長鑫存儲將DDR4產品生命周期終結速度提前，使其2026年底DDR4月產能僅剩1萬片，較原先規畫的2萬片腰斬，讓整體市場供需比維持在88%至91%的緊繃區間，研判價格將挺到2026年底仍不鬆動。"
            },
            {
              "text": "在個股方面，摩根士丹利證券直接把華邦電推向族群首選，合理價估到88元。金控投顧則看好南亞科在DDR4供不應求與DDR5續漲挹注下，明年第一季ASP仍能跳增25%，EPS上看19.5元，將目標價拉升至180元。群聯方面，通路端回報CSP近期將AI伺服器與一般伺服器儲存需求從原本的250～300EB大幅上調至400～450EB，在供給有限、QLC與TLC eSSD報價同步走揚的條件下，手握大量NAND庫存的群聯被視為最大受惠者。"
            },
            {
              "text": "◎《FTNN新聞網》提醒您：本資料僅供參考，投資人應獨立判斷，審慎評估並自負投資風險。"
            }
          ],
          "comment": []
        },
        {
              "url": "https://tw.news.yahoo.com/tag/清潔隊員",
              "group": "綜合",
              "channel": "民視新聞網",
              "cover_img": {
                "src": "https://s.yimg.com/ny/api/res/1.2/jwxNcDmCVxeuHSPp.3FfGg--/YXBwaWQ9aGlnaGxhbmRlcjt3PTk2MDtoPTY4MDtjZj13ZWJw/https://media.zenfs.com/zh-tw/bcc.com.tw/2a7b8cf6fb30bbe32f5abd6cac5c95bf",
                "alt": "因該新聞未提供圖片，此處使用示意圖，請讀者以內文為準。"
              },
              "title": "清潔隊員轉送32元電鍋給拾荒婦遭判刑 清潔隊長說話了",
              "publish_date": "2025/12/02 00:00",
              "detail": [
                {
                  "text": "台北市環保局一名黃姓清潔隊員去（2024）年遭檢舉，將回收車上一個價值32元的電鍋轉送給一名拾荒老婦，被士林地檢署依「貪污治罪條例」起訴；今（2）日士林地方法院一審判處黃員有期徒刑3月、緩刑2年、褫奪公權1年。對此，台北市環保局北投區隊長卓昕岑也表示遺憾，並指出，黃員當下覺得只是送出小小的電鍋，沒想到卻因此觸法，盼黃能保住工作。"
                },
                {
                  "text": "回顧整起事件，去年7月黃員在北投轉運站執勤時，看到回收車上一個價值32元的電鍋狀況良好，便想轉送給附近一位以拾荒維生的老婦，盼她能「煮上一碗熱粥」，讓日子好過一點；沒想到，這樣的善舉卻被檢舉，指控他「竊取或侵占職務上持有之非公用私有器材、財物」，因此黃員也被士林地檢署依「貪污治罪條例」起訴。士林地院今日一審判處黃員有期徒刑3月、緩刑2年、褫奪公權1年。"
                }
              ],
              "keyword": [
                "清潔隊員",
                "電鍋",
                "拾荒婦",
                "貪污治罪條例",
                "士林地檢署",
                "士林地方法院",
                "台北市環保局"
              ],
              "comment": null
            },
            {
          "url": "https://www.ctee.com.tw/news/20251203701542-430704",
          "channel": "工商時報",
          "cover_img": {
            "src": "https://images.ctee.com.tw/newsphoto/2025-11-27/1024/A10AA10_PictureItem_Clipping_03_4.jpg",
            "alt": "圖／美聯社"
          },
          "title": "谷歌400萬片TPU產量無法達成 竟是卡在台積電？分析師：真正大爆發要到2027",
          "publish_date": "2025-12-03",
          "detail": [
            {
              "img": {
                "src": "https://images.ctee.com.tw/newsphoto/2025-11-27/1024/A10AA10_PictureItem_Clipping_03_4.jpg",
                "alt": "圖／美聯社"
              }
            },
            {
              "text": "谷歌自研AI晶片TPU原被市場寄予厚望，外界甚至傳出其2026年將挑戰年產量400萬片，然而，隨著最新供應鏈調查出爐，台積電先進封裝產能不足成為關鍵變數，谷歌TPU的大規模放量恐將延至2027年才真正到來。"
            },
            {
              "text": "摩根士丹利最新發布的報告中，上調谷歌TPU的遠期產量預期，推估2027年產量將達500萬片，並估算每50萬片TPU若用於對外銷售，將為谷歌帶來約130億美元新增收入。此預測點燃市場對谷歌可能啟動AI晶片外售的期待，也讓TPU供應鏈再次成為焦點。"
            },
            {
              "text": "然而，供應鏈端的觀察則顯保守。媒體報導，富邦研究在Jefferies報告中指出，雖然市場傳出Meta有意自2026年起採購TPU，但相關時間表恐受到台積電CoWoS產能限制。研究團隊依據台積電CoWoS建模測算，2026年TPU的可用產量僅落在310萬至320萬片，距離市場傳言的400萬片仍有明顯差距。"
            },
            {
              "text": "多項因素使得台積電短期難以滿足谷歌的龐大需求，包括現有AP8廠處於滿載狀態、新建AP7廠一期產能已被蘋果處理器預留，以及AP7廠二期要至2026年底才能開出，無法支援2026全年的大規模量產。"
            },
            {
              "text": "儘管台積電正評估將部分中低端CoWoS外包給日月光，但外包範圍僅限CPU與網路晶片，所有AI加速器仍須由台積電自行封裝，使TPU的產量在短期內受到嚴格限制。"
            },
            {
              "text": "不過，供應鏈訊號也顯示台積電正積極為2027年的需求高峰做準備。富邦研究最新調查指出，台積電「變得更具進取性」，加速CoWoS產能擴張。最新預測顯示，台積電內部CoWoS月產能將於2026年底提升至12萬片（原預估11萬片），並於2027年底增至14萬片（高於先前預估的13萬片）。分析師認為，一向保守的台積電若開始加速擴產，意味著下游AI訂單動能已趨明確。"
            },
            {
              "text": "隨著2027年產能陸續到位，台積電將能為谷歌主要合作夥伴博通與聯發科提供更多支援。富邦研究預估，2027年谷歌TPU的總產量有望成長至500萬至600萬片，較2026年將近翻倍，並成為谷歌打開AI晶片外銷市場的關鍵轉捩點。"
            },
            {
              "text": "整體而言，2026年仍是產能調整期，而2027年才是谷歌TPU真正的大爆發之年。"
            }
          ],
          "comment": []
        }
          ];
        

  const result = await quickScriptModel(news);
  return res.apiSuccess(result);

}

















































































// 從 DB 拿一筆腳本（你自己調 schema）
/*async function getScriptRowFromDb(newsId) {
  const sql = `
    SELECT news_id, reporter_script, chat_script
    FROM news_data
    WHERE news_id = ?
  `;
  const [rows] = await pool.query(sql, [newsId]);
  return rows[0] || null;
}

// SSE：一個一個送腳本
async function getScript(req, res, next) {
  let query
  let clientClosed = false;

  // 前端關掉連線就不要再寫資料了
  req.on('close', () => {
    clientClosed = true;
  });

  // 設定 SSE header
  res.setHeader('Content-Type', 'text/event-stream; charset=utf-8');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders && res.flushHeaders();

  // 小工具：送一筆 event 給前端
  function sendEvent(data) {
    if (clientClosed) return;
    // SSE 格式：data: ...\n\n
    res.write(`data: ${JSON.stringify(data)}\n\n`);
  }

  try {
    // 1. 先拿到 idList（你可以改成從 body/param 拿）
    const idList = await searchNews(req, res, next); // 假設回傳 Array<number>
    // 如果你的 searchNews 直接回 res，就改成別的 helper，重點是拿到 idList

    // 2. 逐一處理每個 newsId
    for (const newsId of idList) {
      if (clientClosed) break;

      // 2-1 先查 DB 有沒有腳本
      let row = await getScriptRowFromDb(newsId);

      // 2-2 如果沒有，就呼叫外部函式幫你產生腳本 + 寫回 DB
      if (!row) {
        try {
          await runAllWorker(newsId); // 你自己實作：去叫 LLM / 更新 DB
          row = await getScriptRowFromDb(newsId);
        } catch (err) {
          // 產生失敗也可以先丟一個錯誤事件給前端
          sendEvent({ type: 'item-error', newsId, error: err.message || 'buildScript failed' });
          continue; // 換下一筆
        }
      }

      if (!row) {
        // 真的還是沒拿到資料
        sendEvent({ type: 'item-missing', newsId });
      } else {
        // 2-3 有資料就送一筆
        // 這邊你想送什麼欄位就自己挑
        sendEvent({
          type: 'item',
          newsId: row.news_id,
          reporterScript: row.reporter_script,
          chatScript: row.chat_script
        });
      }
    }

    // 3. 全部結束，通知前端 done
    sendEvent({ type: 'done' });
    res.end();
  } catch (err) {
    // 出錯時可以丟一個 error 事件，然後交給 next
    if (!clientClosed) {
      sendEvent({ type: 'error', message: err.message || 'unknown error' });
      res.end();
    }
    next(err);
  }
}*/

/*async function getReporterChatText(idList) {
  // 若沒有 id，直接回傳空陣列
  if (!Array.isArray(idList) || idList.length === 0) {
    return [];
  }

  const sql = `
    SELECT
      nd.news_id,
      nd.reporter_script,
      nc.chat_speaker,
      nc.chat_text,
      nc.chat_order
    FROM news_data AS nd
    LEFT JOIN news_chat AS nc
      ON nc.news_id = nd.news_id
    WHERE nd.news_id IN (?)
    ORDER BY nd.news_id ASC, nc.chat_order ASC;
  `;
  const params = [idList];

  try {
    const [rows] = await pool.query(sql, params);

    // 用 Map 依 news_id 分組
    const map = new Map();

    for (const row of rows) {
      const id = row.news_id;

      if (!map.has(id)) {
        map.set(id, {
          id,
          reporter: row.reporter_script || null,
          chat: []
        });
      }

      // 如果 news_chat 還沒有資料（LEFT JOIN 回來可能是 null），就不要 push
      if (row.chat_speaker != null || row.chat_text != null) {
        map.get(id).chat.push({
          speak: row.chat_speaker,
          text: row.chat_text
        });
      }
    }

    // 如果某些 id 在 news_chat 完全沒有資料，上面的迴圈不會建立，
    // 但你可能仍希望它們出現在結果中，所以另外補齊：
    for (const id of idList) {
      if (!map.has(id)) {
        // 重新查 rows 找對應 reporter_script
        const row = rows.find(r => r.news_id === id);
        map.set(id, {
          id,
          reporter: row ? row.reporter_script : null,
          chat: []
        });
      }
    }

    return Array.from(map.values());
  } catch (err) {
    console.error('[getReporterChatText] database search error:', err);
    throw err;
  }
}*/


/*async function getIdList() {
  let sql = `
    SELECT DISTINCT nd.news_id
    FROM news_data AS nd
    LEFT JOIN news_task AS nt ON nt.news_id = nd.news_id
    WHERE nt.news_id IS NULL OR (nt.reporter_script = 1 AND nt.chat_script = 1)
    ORDER BY nd.created_at DESC
    LIMIT 100;
  `;
  try {
    let [row] = await pool.query(sql);
    return row.map(r => r.news_id);
  } catch (err) {
    console.error("[getIdList] database search error")
  }
}*/

// 取得 一般朗讀 + 新聞播報 + 聊天對白 腳本
/*async function getScript(req, res, next) {

  // 取得播放順序
  let idList;
  try {
    idList = await getIdList();
  } catch (err) {
    err.desc = "middlewares-generalScript(): getIdList() Error";
  }

  let general = await getText(idList);
  let reporterchat = await getReporterChatText(idList);

  // 先把兩組資料轉成 Map，方便用 id 找
  const generalMap = new Map(general.map(g => [g.id, g]));
  const reporterMap = new Map(reporterchat.map(r => [r.id, r]));

  // 依照 idList 的順序組合結果
  const result = idList.map(id => {
    const g = generalMap.get(id) || {};
    const r = reporterMap.get(id) || {};

    return {
      id,
      title:    g.title     || '',
      general:  g.text      || '',       // 把 text 變成 general
      reporter: r.reporter  || '',
      chat:     r.chat      || ''        // 如果你想要陣列可改成 r.chat || []
    };
  });

  // 如果需要回傳：
  return res.apiSuccess(result, "get scripts success");
}*/

/*async function generalScript(req, res, next) {
    let { id, idList, times, limit } = req.query ?? {}

    try {
      [ id, idList, times, limit ] = await checkRequireField ([
        { field: 'id'     , data: id      , type: 'number'  , other: ['lth'] },
        { field: 'idList' , data: idList  , type: 'array'   , other: ['lth'], array_filter: 'number' },
        { field: 'times'  , data: times   , type: 'number'  , other: ['non_null'] , default: 1},
        { field: 'limit'  , data: limit   , type: 'number'  , other: ['non_null'] , default: 300}
      ]);
    } catch (err) {
      err.desc = "middlewares-updateGroupOrder(): Missing or Invalid required fields";
      return next(err);
    }

    // 沒有 idList，呼叫 searchNews 得到 idList
    if ( !idList ) {
      if (id ) idList = [id];
      else idList = [];
      let fakeReq = {
        query: { mode: "id" , limit: limit},
        body: {}
      }
      try {
        let result = await callAndCatchApiSuccess(searchNews, fakeReq);
        idList.push(...(result?.idList || []));
        //return res.apiSuccess(result, "Search Success");
      } catch (err) {
        err.desc = "middlewares-generalScript(): error";
        return next(err);
      }
    }

    fakeReq = {
      query: { mode: "complex" },
      body: { id: idList}
    }
    try {
      let result = await callAndCatchApiSuccess(searchNews, fakeReq);

      result = result.complexList.map(item => {
        const bodyText = (item.newsBody || [])
          .filter(part => typeof part.text === 'string' && part.text.trim() !== '')
          .map(part => part.text.trim())
          .join('\n');

        return {
          id: item.newsId,
          title: item.newsTitle,
          text: bodyText
        }
      });
      return res.apiSuccess(result, "Search Success");
    } catch (err) {
      err.desc = "middlewares-scriptController(): error";
      return next(err);
    }
}*/

/*async function reporterScript(req, res, next) {
    let { id } = req.params ?? {}
    // 交給 generalScript 生成的一組id及text，用deepseek 產生 reporterScript

    // 1️⃣ 先呼叫 generalScript 拿原始 {id,title,text}
    let fakeReq = {
      params: {id: id}
    }
    let generalScriptResult;
    try {
      generalScriptResult = await callAndCatchApiSuccess(generalScript, fakeReq);
      //return res.apiSuccess(generalScriptResult);
    } catch (err) {
      err.desc = "middlewares-reporterScript(): call generalScript error";
        return next(err);
    }

    try {
    // 2️⃣ 取得裡面的陣列：可能是 result 或 result.list
    const items = Array.isArray(generalScriptResult)
      ? generalScriptResult
      : generalScriptResult.list ?? [];

    // 3️⃣ 對每一筆丟給 DeepSeek 產生播報稿
    const reporterItems = await Promise.all(
      items.map((item) =>
        callDeepseekReporterScript({
          id: item.id,
          title: item.title,
          text: shortenArticle(item.text)
        }),
      ),
    );

    // 4️⃣ 組回輸出的格式
    let output;
    if (Array.isArray(generalScriptResult)) {
      // 原本就是陣列 → 直接回陣列
      output = reporterItems;
    } else {
      // 原本是物件（例如 { list, total, ... }）→ 保留其它欄位，只把 list 換掉
      output = {
        ...generalScriptResult,
        list: reporterItems,
      };
    }

    return res.apiSuccess(output);
  } catch (err) {
    err.desc = 'middlewares-reporterScript(): call deepseek error';
    return next(err);
  }
}*/


// ---- reporter ----
/*async function reporterScriptFast(req, res, next) {
    let { id, times } = req.params ?? {}
    // 交給 generalScript 生成的一組id及text，用deepseek 產生 reporterScript

    // 1️⃣ 先呼叫 generalScript 拿原始 {id,title,text}
    let fakeReq = {
      params: {id: id}
    }
    let generalScriptResult;
    try {
      generalScriptResult = await callAndCatchApiSuccess(generalScript, fakeReq);
      //return res.apiSuccess(generalScriptResult);
    } catch (err) {
      err.desc = "middlewares-reporterScript(): call generalScript error";
        return next(err);
    }

    try {
    // 2️⃣ 取得裡面的陣列：可能是 result 或 result.list
    const items = Array.isArray(generalScriptResult)
      ? generalScriptResult
      : generalScriptResult.list ?? [];

    // 3️⃣ 對每一筆丟給 DeepSeek 產生播報稿
    const reporterItems = await Promise.all(
      items.map((item) =>
        callDeepseekReporterScript({
          id: item.id,
          title: item.title,
          text: shortenArticle(item.text)
        }),
      ),
    );

    // 4️⃣ 組回輸出的格式
    let output;
    if (Array.isArray(generalScriptResult)) {
      // 原本就是陣列 → 直接回陣列
      output = reporterItems;
    } else {
      // 原本是物件（例如 { list, total, ... }）→ 保留其它欄位，只把 list 換掉
      output = {
        ...generalScriptResult,
        list: reporterItems,
      };
    }

    return res.apiSuccess(output);
  } catch (err) {
    err.desc = 'middlewares-reporterScript(): call deepseek error';
    return next(err);
  }
}*/





























// ---- chat ----
/*async function chatScript(req, res, next) {
    let { id } = req.params ?? {}
    // 交給 generalScript 生成的一組id及text，用deepseek 產生 chatScript
    return;
}

// ---- quick ----
// ========== 快速播放功能 ==========
// 引入 TTS 控制器的內部函數
const { textToSpeechAndSaveInternal } = require('./ttsController');

/**
 * 快速播放腳本生成 API
 * 從資料庫獲取熱門新聞 → 生成播報稿 → 轉換為 MP3
 */
async function quickScript(req, res, next) {
    let { limit } = req.query ?? {};

    try {
      [ limit ] = await checkRequireField ([
        { field: 'limit'  , data: limit   , type: 'number'  , other: ['non_null'] , default: 10}
      ]);
    } catch (err) {
      err.desc = "middlewares-quickScript(): Missing or Invalid required fields";
      return next(err);
    }

    // 1️⃣ 從 searchNews 按熱度排序抓前 N 筆
    let fakeReq = {
      query: { mode: "complex", order: "heat", limit: limit },
      body: {}
    };

    let newsResult;
    try {
      newsResult = await callAndCatchApiSuccess(searchNews, fakeReq);
    } catch (err) {
      err.desc = "middlewares-quickScript(): call searchNews error";
      return next(err);
    }

    // 2️⃣ 提取新聞內容
    const items = newsResult.complexList || [];

    if (items.length === 0) {
      return res.apiSuccess({ scripts: [] }, "No news found");
    }

    // 3️⃣ 對每一筆新聞呼叫本地 Ollama 生成 quick-script
    let quickScripts;
    try {
      quickScripts = await Promise.all(
        items.map((item) => {
          const bodyText = (item.newsBody || [])
            .filter(part => typeof part.text === 'string' && part.text.trim() !== '')
            .map(part => part.text.trim())
            .join('\n');

          return callOllamaQuickScript({
            id: item.newsId,
            title: item.newsTitle,
            text: shortenArticle(bodyText)
          });
        })
      );
    } catch (err) {
      err.desc = 'middlewares-quickScript(): call ollama quick-script error';
      return next(err);
    }

    // 4️⃣ 將生成的播報稿轉換為 MP3 並儲存
    console.log(`[QuickScript] 開始批次 TTS 轉換 ${quickScripts.length} 個播報稿`);

    let audioFiles;
    try {
      audioFiles = await Promise.all(
        quickScripts.map((script) =>
          textToSpeechAndSaveInternal(script.id, script.text)
        )
      );
    } catch (err) {
      console.error('[QuickScript] TTS 轉換錯誤:', err);
      err.desc = 'middlewares-quickScript(): TTS conversion error';
      return next(err);
    }

    // 5️⃣ 組合返回結果
    const results = quickScripts.map((script, index) => ({
      id: script.id,
      title: script.title,
      text: script.text,
      audioFile: audioFiles[index].filename,
      audioPath: audioFiles[index].filepath,
      audioSize: audioFiles[index].fileSize
    }));

    console.log(`[QuickScript] 完成: 生成 ${results.length} 個播報稿及音訊檔案`);

    return res.apiSuccess({ scripts: results }, "Quick Script Generated with Audio");
}

/**
 * 呼叫本地 Ollama 的 quick-script model
 */
async function callOllamaQuickScript({ id, title, text }) {
  const prompt =
    '標題：' + title + '\n' +
    '內容：' + text + '\n\n' +
    '請依照 quick-script 的規則產生簡短的新聞播報稿。';

  const start = Date.now();
  const payload = {
    model: QUICK_SCRIPT_MODEL,
    prompt,
    stream: false,
    options: {
      num_predict: 150
    },
  };

  let resp;
  try {
    resp = await axios.post(OLLAMA_URL, payload, {
      headers: { 'Content-Type': 'application/json' },
      timeout: 10000, // 10秒超時
    });
  } catch (err) {
    if (err.code === 'ECONNABORTED') {
      console.error(`Ollama timeout: quickScript id=${id}`);
    } else {
      console.error(`Ollama error: quickScript id=${id}`, err.message);
    }
    throw err;
  }

  let script = resp.data?.response || '';
  script = cleanNewsScript(script);

  console.log(`quick-script latency(ms) for id ${id}:`, Date.now() - start);

  return {
    id,
    title,
    text: script,
  };
}




/*async function callDeepseekReporterScript({ id, title, text }) {

  // 組 prompt：請 DeepSeek 幫忙改寫成 80~100 字的播報稿
  const prompt =
    '你是一位台灣電視新聞台的記者，請根據以下新聞標題與全文內容，' +
    '撰寫一段約 80 到 100 字的中文播報稿。\n\n' +
    '要求：\n' +
    '1. 保留主要事實與數據，刪去重複內容。\n' +
    '2. 使用口語化、第三人稱播報語氣。\n' +
    '3. 不要加入新的資訊，也不要加標題或說明文字，只輸出播報稿內容本身。\n' +
    '4. 不要說自己是 AI 或模型，不要回答提問，不要給任何建議或安全聲明（例如「如果您有任何問題」等）。\n' +
    '5. 不要輸出「播報稿：」「新聞播報：」等提示語，只輸出內容。\n\n' +
    '【標題】\n' + title + '\n\n' +
    '【內文】\n' + text + '\n\n' +
    '【請開始撰寫播報稿】';


  const system =
    '你是一位電視新聞台的專業播報記者，只負責把輸入的新聞改寫成播報稿。\n' +
    '規則：\n' +
    '1. 每次輸出一段 80~100 個字的中文播報稿。\n' +
    '2. 用口語化、第三人稱的電視新聞播報語氣。\n' +
    '3. 只保留關鍵事實與數字，不新增任何資訊或評論。\n' +
    '4. 不得出現「我是AI」「身為AI」「如果您有任何問題」等類似字句。\n' +
    '5. 不得加上標題、說明文字或「播報稿：」「新聞內容：」等提示語。\n' +
    '若違反以上任一條規則，視為錯誤回答。';
  const prompt =
    title + '\n' +
    text + '\n\n' +
    '請依規則產生播報稿。';
  const prompt =
    '將下列新聞改寫成約 60 到 80 字的中文電視新聞播報稿。' +
    '口語化、第三人稱，只保留關鍵事實與數字，不新增資訊或評論，' +
    '不要加標題或說明文字，也不要提到自己或 AI 身分。\n\n' +
    '【標題】\n' + title + '\n\n' +
    '【內文】\n' + text + '\n\n' +
    '請直接輸出播報稿內容。';

  const start = Date.now();
  const payload = {
    model: OLLAMA_MODEL,
    system,
    prompt,
    stream: false,
    options: {
      num_predict: 256
    },
  };

  let resp;
  try {
    resp = await axios.post(OLLAMA_URL, payload, {
      headers: { 'Content-Type': 'application/json' },
      //timeout: 5000, // ⏱ 最多給 5 秒，超過就丟錯
    });
  } catch (err) {
    // 這裡是「思考超過 5 秒」或其他連線錯誤的處理
    if (err.code === 'ECONNABORTED') {
      // timeout
      console.error(`DeepSeek timeout: reporterScript id=${id}`);
    } else {
      console.error(`DeepSeek error: reporterScript id=${id}`, err.message);
    }
    // 讓外層的 try/catch 處理這個錯誤
    throw err;
  }

  let script = resp.data?.response || '';

  script = cleanNewsScript(script);

  console.log('deepseek latency(ms):', Date.now() - start);

  // 回傳保持 {id, title, text} 結構，只把 text 換成播報稿
  return {
    id,
    title,
    text: script,
  };
}*/

// ---- call ask.sh ----
async function callAskScript(req, res, next) {
  try {
    const { question } = req.body;
    const scriptPath = path.join(__dirname, "../ask.sh"); // 指向 ask.sh 檔案

    execFile("bash", [scriptPath, question], (error, stdout, stderr) => {
      if (error) {
        console.error("執行 ask.sh 出錯：", stderr);
        return res.status(500).json({ error: "Failed to execute ask.sh" });
      }

      const response = stdout.trim();
      res.json({ response });
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to execute ask.sh" });
  }
}

// ---- 匯出所有函式 ----
module.exports = {
  getText,
  getScript,
  getQuickScipt,
  quickScript,  // 新增：快速播放功能
  callAskScript
};