// 設定與建立 Express 應用實體
const express = require('express');
const cors = require('cors');
const pool = require('./connect_db')

const app = express(); // Express app 實體
app.use(cors());
app.use(express.json());    // 解析 JSON body

// 回應中介
const responseWrapper = require('./utils/responseWrapper');
app.use(responseWrapper);

// 權限檢查路由
const permissionRoutes = require('./routes/permission');
app.use('/api/permission', permissionRoutes);

// 清除資料庫資料 + AUTO_INCREMENT 重數
const cleanHelper = require('./utils/cleanHelper');
app.get('/clean', cleanHelper);

const channelRoutes = require('./routes/channel');
app.use('/api/channel', channelRoutes);

// router 設定
const routes = require('./routes/index');
app.use('/api', routes);

// 測試-首頁
app.get('/', (req, res) => {
    res.send('Hello, World!');
});

// 測試-全局錯誤處理中間件
app.get('/error', (req, res, next) => {
    const error = new Error('This is a test error');
    next(error);
});

// 全局錯誤處理中間件
app.use((err, req, res, next) => {
    
    // 打印錯誤訊息
    console.error(err);

    // 錯誤訊息插入資料庫
    const sql = 'INSERT INTO error_logs (error_message, error_description, error_stack) VALUES (?, ?, ?)';
    const params = [ err.message, err.desc || null, err.stack ];
    pool.query(sql, params, (dbErr, next) => {
         if (dbErr) {
            console.error('Failed to log error to database:', dbErr);
        } else {
            console.log('Error logged to database');
        }
    })
    // 回覆錯誤訊息
    res.apiError(err, err.status || 500);
    
});

module.exports = app;
