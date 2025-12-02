// openaiClient.js

/*require('dotenv').config({
  path: require('path').join(__dirname, '..', '.env')  // 指到 back_end/.env
});

const OpenAI = require("openai");

const client = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

module.exports = client;*/

const OpenAI = require('openai');



const client = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,  // ⭐ 用環境變數
});

// 可選：偵錯用，正式環境可以刪掉
if (!process.env.OPENAI_API_KEY) {
  console.error('⚠️ OPENAI_API_KEY 沒有讀到，請檢查 .env / dotenv 設定');
}

module.exports = client;
