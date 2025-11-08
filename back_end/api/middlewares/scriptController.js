const pool = require('../connect_db');
const { checkRequireField } = require('../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');
const { execFile } = require('child_process');
const path = require('path');
const { searchNews } = require('./newsController');

// ---- general ----
async function generalScript(req, res, next) {
    let { id } = req.params ?? {}

    idList = id;

    let fakeReq = {
        body: {}
    }
    try {
        let result = await callAndCatchApiSuccess(searchNews, fakeReq);
        console.log("result", result);
        return res.apiSuccess(result, "Search Success");
    } catch (err) {
        err.desc = "middlewares-scriptController(): error";
    }


    // 先 genreate 一組 idList (searchNews {})
    // 下一個 >> remove 第一個，聽第一個 
    // 剩最後1個時再自動用最後1個id繼續 generate

    //  [ {"text"}, {"text"}, {"text"} ]
    return;
}

// ---- reporter ----
async function reporterScript(req, res, next) {
    let { id } = req.params ?? {}
    // 交給 generalScript 生成的一組id及text，用deepseek 產生 reporterScript
    return;
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
  generalScript,
  reporterScript,
  chatScript,
  quickScript,
  callAskScript
};
