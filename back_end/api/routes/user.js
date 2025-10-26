const express = require('express');
const router = express.Router();
const { searchUser, insertUser, updateUser, deleteUser } = require('../middlewares/userController');
const { searchUserAction, insertUserAction, updateUserAction, deleteUserAction } = require('../middlewares/actionController');
const { getClientIp } = require('../utils/clientHelper');

// ============================================
// 基礎使用者操作（原有）
// ============================================

// 搜尋使用者
router.get('/', searchUser);
router.get('/:id', searchUser);

// 登入
router.post('/login', searchUser);

// 註冊
router.post('/signup', insertUser);

// update
router.put('/', updateUser);

router.get('/:actionType/:dataType', searchUserAction);
router.post('/:actionType/:dataType', getClientIp, insertUserAction);
router.put('/:actionType/:targetId', updateUserAction);
router.delete('/:actionType/:targetId', deleteUserAction);

// ============================================
// 會員功能路由（統一通過 updateUser）
// ============================================

/**
 * 統一的會員管理路由
 * 根據 req.body 中的 action 字段執行不同操作
 * 
 * 支援的 action：
 * - 'update-profile': 更新個人資料（姓名、生日、手機、郵箱）
 * - 'change-password': 修改密碼
 * - 'delete-account': 刪除帳號
 * - 'send-email-code': 發送郵箱驗證碼
 * - 'verify-email-code': 驗證郵箱
 * - 'send-phone-code': 發送手機驗證碼
 * - 'verify-phone-code': 驗證手機
 * - 'update-location': 更新地點資訊（原有）
 */
router.put('/', updateUser);

router.delete('/', async (req, res, next) => {
    res.send('This is the delete route');
});

module.exports = router;