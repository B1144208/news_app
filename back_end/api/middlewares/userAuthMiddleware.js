// middlewares/userAuthMiddleware.js
// 這是一個簡化的認證中間件，用於用戶資料相關的API

const jwt = require('jsonwebtoken');
const { apiError } = require('../utils/responseWrapper');
const db = require('../connect_db');

// 用戶認證中間件
const authenticateUser = async (req, res, next) => {
    try {
        const authHeader = req.headers.authorization;
        const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

        if (!token) {
            // 如果沒有token，但可能有session，嘗試使用session
            if (req.session && req.session.userId) {
                req.user = { id: req.session.userId };
                return next();
            }
            
            return res.json(apiError('需要認證', null));
        }

        // 驗證JWT token（如果您使用JWT）
        try {
            // 這裡使用您的JWT密鑰
            const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key';
            const decoded = jwt.verify(token, JWT_SECRET);
            
            // 驗證用戶是否存在
            const [users] = await db.execute(
                'SELECT user_id, user_account FROM user_profile WHERE user_id = ?',
                [decoded.userId]
            );
            
            if (users.length === 0) {
                return res.json(apiError('用戶不存在', null));
            }
            
            req.user = {
                id: users[0].user_id,
                account: users[0].user_account
            };
            
            next();
        } catch (jwtError) {
            return res.json(apiError('無效的認證令牌', null));
        }
    } catch (error) {
        console.error('認證中間件錯誤:', error);
        return res.json(apiError('認證失敗', null));
    }
};

// 可選的用戶認證中間件（允許未認證用戶通過）
const optionalAuthenticateUser = async (req, res, next) => {
    try {
        const authHeader = req.headers.authorization;
        const token = authHeader && authHeader.split(' ')[1];

        if (!token) {
            // 如果有session
            if (req.session && req.session.userId) {
                req.user = { id: req.session.userId };
            }
            return next();
        }

        try {
            const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key';
            const decoded = jwt.verify(token, JWT_SECRET);
            
            const [users] = await db.execute(
                'SELECT user_id, user_account FROM user_profile WHERE user_id = ?',
                [decoded.userId]
            );
            
            if (users.length > 0) {
                req.user = {
                    id: users[0].user_id,
                    account: users[0].user_account
                };
            }
        } catch (jwtError) {
            // 如果token無效，繼續但不設置用戶
            console.log('可選認證：token無效');
        }
        
        next();
    } catch (error) {
        console.error('可選認證中間件錯誤:', error);
        next();
    }
};

// 生成JWT token的輔助函數
const generateToken = (userId, userAccount) => {
    const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key';
    const payload = {
        userId: userId,
        account: userAccount,
        iat: Math.floor(Date.now() / 1000)
    };
    
    return jwt.sign(payload, JWT_SECRET, { expiresIn: '7d' });
};

// 驗證密碼的輔助函數（基於您現有的passwordHelper）
const verifyUserPassword = async (inputPassword, storedPassword) => {
    const { verifyPassword } = require('../utils/passwordHelper');
    return await verifyPassword(inputPassword, storedPassword);
};

module.exports = {
    authenticateUser,
    optionalAuthenticateUser,
    generateToken,
    verifyUserPassword
};