// routes/auth.js - 認證路由，連接現有的用戶功能
const express = require('express');
const router = express.Router();
const { searchUser } = require('../middlewares/userController');

// 登入路由 - 重用現有的 searchUser 功能
router.post('/login', (req, res, next) => {
    console.log('收到登入請求:', req.body);
    
    // 直接調用現有的 searchUser 中間件
    // searchUser 在 POST /user/login 時已經處理登入邏輯
    searchUser(req, res, next);
});

// 檢查登入狀態
router.get('/check', async (req, res, next) => {
    try {
        const authHeader = req.headers['authorization'];
        const token = authHeader?.replace('Bearer ', '');
        
        console.log('檢查登入狀態, token:', token);
        
        // 這裡可以添加你的token驗證邏輯
        // 暫時簡單檢查
        if (token && token !== 'null' && token !== 'undefined') {
            return res.json({
                success: true,
                message: '已登入',
                data: {
                    isLoggedIn: true
                }
            });
        } else {
            return res.status(401).json({
                success: false,
                message: '未登入'
            });
        }
        
    } catch (error) {
        console.error('檢查登入狀態異常:', error);
        return res.status(500).json({
            success: false,
            message: '伺服器錯誤'
        });
    }
});

// 登出路由 - 重用現有的用戶登出功能
router.post('/logout', async (req, res, next) => {
    try {
        console.log('用戶登出');
        return res.json({
            success: true,
            message: '登出成功'
        });
    } catch (error) {
        console.error('登出異常:', error);
        return res.status(500).json({
            success: false,
            message: '伺服器錯誤'
        });
    }
});

module.exports = router;