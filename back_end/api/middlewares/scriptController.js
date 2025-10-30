const pool = require('../connect_db');
const { checkRequireField } = require('../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');
const { execFile } = require('child_process');
const path = require('path');

// ---- general ----
async function generalScript(req, res, next) {
    return;

}

// ---- reporter ----
async function reporterScript(req, res, next) {
  return;
}

// ---- chat ----
async function chatScript(req, res, next) {
  return;
}

// ---- quick ----
async function quickScript(req, res, next) {
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
