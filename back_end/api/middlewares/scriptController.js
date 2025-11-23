const pool = require('../connect_db');
const { checkRequireField } = require('../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');
const { execFile } = require('child_process');
const path = require('path');
const { searchNews } = require('./newsController');
const axios = require('axios');

const OLLAMA_URL = 'http://localhost:11434/api/generate';
const OLLAMA_MODEL = 'qwen2.5:1.5b';

/*
@ general, reporter, chat: 給予一個 List {"id", "title", "text"}
@ general: 僅 news_body
@ reporter: 記者播報
@ chat: 聊天對白
@
*/

// ---- general ----
async function generalScript(req, res, next) {
    let { id, times } = req.params ?? {}

    try {
        [ id, times ] = await checkRequireField ([
            { field: 'id'   , data: id    , type: 'number' , other: ['lth'] },
            { field: 'times', data: times , type: 'number' , other: ['non_null'] , default: 1}
        ]);
    } catch (err) {
        err.desc = "middlewares-updateGroupOrder(): Missing or Invalid required fields";
        return next(err);
    }

    // ****************************************************************************
    limit = 2;

    idList = [id];

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

    // 先 genreate 一組 idList (searchNews {})
    // 下一個 >> remove 第一個，聽第一個 
    // 剩最後1個時再自動用最後1個id繼續 generate

    //  [ {"text"}, {"text"}, {"text"} ]
    //return;
}

// ---- reporter ----
async function reporterScript(req, res, next) {
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
    const reporterItems = [];
    for (const item of items) {
      const result = await callDeepseekReporterScript({
        id: item.id,
        title: item.title,
        text: item.text //shortenArticle(item.text, 4),
      });
      reporterItems.push(result);
    }
    /*const reporterItems = await Promise.all(
      items.map((item) =>
        callDeepseekReporterScript({
          id: item.id,
          title: item.title,
          text: item.text,
        }),
      ),
    );*/

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
}

// ---- chat ----
async function chatScript(req, res, next) {
    let { id } = req.params ?? {}
    // 交給 generalScript 生成的一組id及text，用deepseek 產生 chatScript
    return;
}

// ---- quick ----
async function quickScript(req, res, next) {
    // 用熱度高id直接生成一組id
    return;
}

/*function shortenArticle(text, maxSentences = 4) {
  if (!text) return '';

  // 粗暴做法：用全形句號切段
  const parts = text.split(/。/);
  const head = parts.slice(0, maxSentences).join('。');

  return head + (head.endsWith('。') ? '' : '。');
}*/

function cleanNewsScript(raw) {
  if (!raw) return '';

  // 先切行＋去掉前後空白＋濾掉空白行
  const lines = raw
    .split(/\r?\n/)
    .map(l => l.trim())
    .filter(Boolean);

  const filtered = lines.filter(line => {
    // 把跟「我是AI、回答問題、安全聲明」有關的句子砍掉
    return !(
      /作為.?AI/i.test(line) ||
      /作為一個?人工智慧/i.test(line) ||
      /身為.?AI/i.test(line) ||
      /我是一個?AI/i.test(line) ||
      /無法提供(醫療|法律)建議/.test(line) ||
      /不能替代專業(醫療|法律)/.test(line) ||
      /如果您有任何問題/.test(line) ||
      /如果你有任何問題/.test(line) ||
      /建議您尋求專業/.test(line) ||
      /僅供參考/.test(line) ||
      /感謝你的提問/.test(line) ||
      /感謝您的提問/.test(line) ||
      /回答你的問題是/.test(line) ||
      /回答您的問題是/.test(line) ||
      /超出我的能力範圍/.test(line)
    );
  });

  let cleaned = filtered.join('\n').trim();

  // 再把「播報稿：」「新聞播報：」之類開頭字眼拿掉
  cleaned = cleaned.replace(/^(播報稿|新聞播報|以下是播報內容)[：:\s]*/i, '');

  return cleaned;
}

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


async function callDeepseekReporterScript({ id, title, text }) {

  // 組 prompt：請 DeepSeek 幫忙改寫成 80~100 字的播報稿
  /*const prompt =
    '你是一位台灣電視新聞台的記者，請根據以下新聞標題與全文內容，' +
    '撰寫一段約 50 到 60 字的中文播報稿。\n\n' +
    '要求：\n' +
    '1. 保留主要事實與數據，刪去重複內容。\n' +
    '2. 使用口語化、第三人稱播報語氣。\n' +
    '3. 不要加入新的資訊，也不要加標題或說明文字，只輸出播報稿內容本身。\n' +
    '4. 不要說自己是 AI 或模型，不要回答提問，不要給任何建議或安全聲明（例如「如果您有任何問題」等）。\n' +
    '5. 不要輸出「播報稿：」「新聞播報：」等提示語，只輸出內容。\n\n' +
    '【標題】\n' + title + '\n\n' +
    '【內文】\n' + text + '\n\n' +
    '【請開始撰寫播報稿】';
  */

  const system = 
    '你是一位台灣電視新聞台的專業播報記者，只負責把輸入的新聞改寫成播報稿。\n' +
    '規則：\n' +
    '1. 每次輸出一段 80~100 個字的中文播報稿。\n' +
    '2. 用口語化、第三人稱的電視新聞播報語氣。\n' +
    '3. 只保留關鍵事實與數字，不新增任何資訊或評論。\n' +
    '4. 不得出現「我是AI」「身為AI」「如果您有任何問題」等類似字句。\n' +
    '5. 不得加上標題、說明文字或「播報稿：」「新聞內容：」等提示語。\n' +
    '6. 輸出內容中嚴禁出現「【」或「】」這兩個符號。\n' +
    '若違反以上任一條規則，視為錯誤回答。';
  const prompt = 
    '【標題】\n' + title + '\n\n' +
    '【內文】\n' + text + '\n\n' +
    '請依規則產生播報稿。';
  /*onst prompt =
    '將下列新聞改寫成約 60 到 80 字的中文電視新聞播報稿。' +
    '口語化、第三人稱，只保留關鍵事實與數字，不新增資訊或評論，' +
    '不要加標題或說明文字，也不要提到自己或 AI 身分。\n\n' +
    '【標題】\n' + title + '\n\n' +
    '【內文】\n' + text + '\n\n' +
    '請直接輸出播報稿內容。';*/
  
  const start = Date.now();
  const payload = {
    model: OLLAMA_MODEL,
    system,
    prompt,
    stream: false,
    options: {
      num_predict: 80
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

  // 如果 DeepSeek 有 <think>...</think> 先清掉
  script = script.replace(/<think>[\s\S]*?<\/think>/g, '').trim();

  // 再用我們的清理函式，把 AI 自我介紹、免責聲明拿掉
  script = cleanNewsScript(script);

  console.log('deepseek latency(ms):', Date.now() - start);

  // 回傳保持 {id, title, text} 結構，只把 text 換成播報稿
  return {
    id,
    title,
    text: script,
  };
}

// ---- 匯出所有函式 ----
module.exports = {
  generalScript,
  reporterScript,
  chatScript,
  quickScript,
  callAskScript
};
