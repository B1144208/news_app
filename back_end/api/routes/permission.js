// routes/permission.js
const express = require('express');
const router = express.Router();
const { getPermissionInfo, checkActionPermission } = require('../utils/authPermissionMiddleware');

// 獲取當前用戶權限信息
router.get('/info', getPermissionInfo);

// 檢查特定操作權限
router.get('/check/:actionType', checkActionPermission, (req, res) => {
    const { actionType } = req.params;
    const userPermissions = req.userPermissions;
    
    return res.json({
        success: true,
        message: '權限檢查成功',
        data: {
            action: actionType,
            hasPermission: userPermissions.allowedActions.includes(actionType),
            userPermissions: userPermissions
        }
    });
});

module.exports = router;