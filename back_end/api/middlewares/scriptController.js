const pool = require('../connect_db');
const { checkRequireField } = require('../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');
const { execFile } =  require("child_process");
import path from "path";

// search
async function generalScript (req, res, next) {
    return;
}

// insert
async function reporterScript (req, res, next) {
    return;
}

// update
async function chatScript(req, res, next) {
    return;
}

// delete
async function quickScript(req, res, next) {
    return;
}




export async function callAskScript(question) {
  return new Promise((resolve, reject) => {
    const scriptPath = path.join(__dirname, "../ask.sh"); // 指向 ask.sh

    execFile("bash", [scriptPath, question], (error, stdout, stderr) => {
      if (error) {
        console.error("執行 ask.sh 出錯：", stderr);
        reject(error);
      } else {
        resolve(stdout.trim());
      }
    });
  });
}


module.exports = {
    generalScript,
    reporterScript,
    chatScript,
    quickScript
}