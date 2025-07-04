// 設定與建立 Express 應用實體
const express = require('express');
const cors = require('cors');
const routes = require('./routes');

const app = express(); // Express app 實體
app.use(cors());
app.use(express.json());

// router 設定
app.use('/api', routes);

// 測試首頁
app.get('/', (req, res) => {
    res.send('Hello, World!');
});

module.exports = app;