const express = require('express')
const router = express.Router()
const { searchUser, insertUser, updateUser, deleteUser } = require('../middlewares/userController');
const { searchUserAction, insertUserAction, updateUserAction, deleteUserAction } = require('../middlewares/actionController');
const { getClientIp } = require('../utils/clientHelper')
const { checkPassword, hashPassword } = require('../utils/passwordHelper');
const { apiSuccess, apiError } = require('../utils/responseWrapper');
const { checkRequireField } = require('../utils/checkHelper');
const db = require('../connect_db');

// 原有的路由
// search
router.get('/', searchUser);
router.get('/:id', searchUser);

// login / signup
router.post('/login', searchUser);
router.post('/signup', insertUser);

// update
router.put('/', updateUser);

// delete
router.delete('/', async (req, res, next) => {
    res.send('This is the delete route');
});

// user_action
router.get('/:actionType/:dataType', searchUserAction);
router.post('/:actionType/:dataType', getClientIp, insertUserAction);
router.put('/:actionType/:targetId', updateUserAction);
router.delete('/:actionType/:targetId', deleteUserAction);


// ======= 新增的會員功能路由 =======

// 更新用戶資料
router.put('/profile', async (req, res) => {
    try {
        const { field, value } = req.body;
        const userId = req.user?.id || req.session?.userId || req.body.userId;

        if (!userId) {
            return res.json(apiError('未登錄', null));
        }

        // 驗證必要字段
        if (!field || value === undefined) {
            return res.json(apiError('缺少必要參數', null));
        }

        // 字段映射：前端字段名 -> 數據庫字段名
        const fieldMapping = {
            'name': 'user_name',
            'phone': 'user_phone',
            'birthdate': 'user_birthday',
            'email': 'user_email'
        };

        const dbField = fieldMapping[field];
        if (!dbField) {
            return res.json(apiError('不允許更新此字段', null));
        }

        // 如果更新email，檢查是否已存在
        if (field === 'email') {
            const [existingUsers] = await db.execute(
                'SELECT user_id FROM user_profile WHERE user_email = ? AND user_id != ?',
                [value, userId]
            );
            
            if (existingUsers.length > 0) {
                return res.json(apiError('此信箱已被使用', null));
            }
        }

        // 更新數據庫
        await db.execute(
            `UPDATE user_profile SET ${dbField} = ? WHERE user_id = ?`,
            [value, userId]
        );

        res.json(apiSuccess('更新成功', null));
    } catch (error) {
        console.error('更新用戶資料錯誤:', error);
        res.json(apiError('伺服器錯誤', null));
    }
});

// 修改密碼
router.put('/change-password', async (req, res) => {
    try {
        const { currentPassword, newPassword } = req.body;
        const userId = req.user?.id || req.session?.userId || req.body.userId;

        if (!userId) {
            return res.json(apiError('未登錄', null));
        }

        // 驗證必要字段
        if (!currentPassword || !newPassword) {
            return res.json(apiError('請提供原密碼和新密碼', null));
        }

        // 驗證新密碼長度
        if (newPassword.length < 6) {
            return res.json(apiError('新密碼長度至少6位', null));
        }

        // 獲取用戶當前密碼
        const [users] = await db.execute(
            'SELECT user_password FROM user_profile WHERE user_id = ?',
            [userId]
        );

        if (users.length === 0) {
            return res.json(apiError('用戶不存在', null));
        }

        // 使用您現有的checkPassword驗證原密碼
        const isCurrentPasswordValid = await checkPassword(currentPassword, users[0].user_password);
        if (!isCurrentPasswordValid) {
            return res.json(apiError('原密碼錯誤', null));
        }

        // 使用您現有的hashPassword加密新密碼
        const hashedNewPassword = await hashPassword(newPassword);

        // 更新密碼
        await db.execute(
            'UPDATE user_profile SET user_password = ? WHERE user_id = ?',
            [hashedNewPassword, userId]
        );

        res.json(apiSuccess('密碼修改成功', null));
    } catch (error) {
        console.error('修改密碼錯誤:', error);
        res.json(apiError('伺服器錯誤', null));
    }
});

// 獲取用戶設定
router.get('/settings', async (req, res) => {
    try {
        const userId = req.user?.id || req.session?.userId || req.query.userId;

        if (!userId) {
            return res.json(apiError('未登錄', null));
        }

        // 從user_profile表獲取設定
        const [users] = await db.execute(`
            SELECT 
                user_notification,
                user_ai_mode,
                user_ai_sound
            FROM user_profile 
            WHERE user_id = ?
        `, [userId]);

        if (users.length === 0) {
            return res.json(apiError('用戶不存在', null));
        }

        const user = users[0];

        // AI模式映射
        const aiModeMapping = {
            0: '關閉',
            1: '聊天模式',
            2: '播報模式'
        };

        // 語言設定（可能需要從其他地方獲取，或使用默認值）
        const userSettings = {
            language: '繁體中文', // 默認值，或從其他表獲取
            notifications: user.user_notification === 1,
            aiReading: aiModeMapping[user.user_ai_mode] || '聊天模式',
            aiSound: user.user_ai_sound
        };

        res.json(apiSuccess('獲取設定成功', { settings: userSettings }));
    } catch (error) {
        console.error('獲取用戶設定錯誤:', error);
        res.json(apiError('伺服器錯誤', null));
    }
});

// 更新用戶設定
router.put('/settings', async (req, res) => {
    try {
        const { key, value } = req.body;
        const userId = req.user?.id || req.session?.userId || req.body.userId;

        if (!userId) {
            return res.json(apiError('未登錄', null));
        }

        if (!key || value === undefined) {
            return res.json(apiError('缺少必要參數', null));
        }

        let updateField = null;
        let updateValue = value;

        // 根據設定項映射到對應的數據庫字段
        switch (key) {
            case 'notifications':
                updateField = 'user_notification';
                updateValue = value ? 1 : 0;
                break;
            case 'aiReading':
                updateField = 'user_ai_mode';
                // AI模式反向映射
                const aiModeReverseMapping = {
                    '關閉': 0,
                    '聊天模式': 1,
                    '播報模式': 2
                };
                updateValue = aiModeReverseMapping[value] !== undefined ? aiModeReverseMapping[value] : 1;
                break;
            case 'aiSound':
                updateField = 'user_ai_sound';
                updateValue = parseInt(value) || 0;
                break;
            case 'language':
                // 語言設定可能需要存儲在其他地方，這裡先忽略
                return res.json(apiSuccess('語言設定暫不支持', null));
            default:
                return res.json(apiError('不允許的設定項', null));
        }

        if (updateField) {
            await db.execute(
                `UPDATE user_profile SET ${updateField} = ? WHERE user_id = ?`,
                [updateValue, userId]
            );
        }

        res.json(apiSuccess('設定更新成功', null));
    } catch (error) {
        console.error('更新用戶設定錯誤:', error);
        res.json(apiError('伺服器錯誤', null));
    }
});

// 用戶登出
router.post('/logout', async (req, res) => {
    try {
        const userId = req.user?.id || req.session?.userId || req.body.userId;

        // 記錄登出行為到現有的表中（如果有相關表的話）
        if (userId) {
            try {
                // 這裡可以記錄到現有的用戶行為表，如果沒有則可以省略
                console.log(`用戶 ${userId} 執行登出操作`);
            } catch (e) {
                console.error('記錄登出行為錯誤:', e);
            }
        }

        // 清除session（如果使用session）
        if (req.session) {
            req.session.destroy((err) => {
                if (err) {
                    console.error('清除session錯誤:', err);
                }
            });
        }

        res.json(apiSuccess('登出成功', null));
    } catch (error) {
        console.error('登出錯誤:', error);
        res.json(apiError('伺服器錯誤', null));
    }
});

// 刪除帳號
router.delete('/account', async (req, res) => {
    try {
        const userId = req.user?.id || req.session?.userId || req.body.userId;

        if (!userId) {
            return res.json(apiError('未登錄', null));
        }

        // 開始數據庫事務
        await db.execute('START TRANSACTION');

        try {
            // 記錄刪除行為
            console.log(`用戶 ${userId} 執行刪除帳號操作`);

            // 根據您的數據庫結構，刪除相關的用戶數據
            // 注意：由於您可能有外鍵約束，需要按正確的順序刪除
            
            // 先刪除依賴於user_profile的數據（如果有的話）
            // 例如：用戶的新聞收藏、評論等
            
            // 最後刪除用戶主記錄
            const [result] = await db.execute(
                'DELETE FROM user_profile WHERE user_id = ?',
                [userId]
            );

            if (result.affectedRows === 0) {
                await db.execute('ROLLBACK');
                return res.json(apiError('用戶不存在', null));
            }

            // 提交事務
            await db.execute('COMMIT');

            // 清除session
            if (req.session) {
                req.session.destroy((err) => {
                    if (err) {
                        console.error('清除session錯誤:', err);
                    }
                });
            }

            res.json(apiSuccess('帳號已刪除', null));
        } catch (error) {
            // 回滾事務
            await db.execute('ROLLBACK');
            throw error;
        }
    } catch (error) {
        console.error('刪除帳號錯誤:', error);
        res.json(apiError('刪除帳號失敗', null));
    }
});

module.exports = router