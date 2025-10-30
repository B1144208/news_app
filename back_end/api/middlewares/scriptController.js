const pool = require('../connect_db');
const { checkRequireField } = require('../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');
const { execFile } = require('child_process');
const path = require('path');

// ---- search ----
async function generalScript(req, res, next) {
  return;
}

// ---- insert ----
async function reporterScript(req, res, next) {
  return;
}

// ---- update ----
async function chatScript(req, res, next) {
  return;
}

// ---- delete ----
async function quickScript(req, res, next) {
  return;
}

// ---- 呼叫 ask.sh 腳本 ----
async function callAskScript(question) {
  return new Promise((resolve, reject) => {
    const scriptPath = path.join(__dirname, '../ask.sh'); // 指向 ask.sh 檔案

    execFile('bash', [scriptPath, question], (error, stdout, stderr) => {
      if (error) {
        console.error('執行 ask.sh 出錯：', stderr);
        reject(error);
      } else {
        resolve(stdout.trim());
      }
    });
  });
}

// ---- 匯出所有函式 ----
module.exports = {
  generalScript,
  reporterScript,
  chatScript,
  quickScript,
  callAskScript
};
