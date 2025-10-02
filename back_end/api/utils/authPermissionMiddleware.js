// authPermissionMiddleware.js
// 權限控制中介軟體 - 處理已登入/未登入用戶的功能權限

const pool = require('../connect_db'); // 添加資料庫連接

// 驗證 token 並獲取用戶資訊
const verifyToken = async (token) => {
    try {
        // 簡單的 token 驗證（您可以根據需要改用 JWT）
        if (token === 'secret123') {
            return { isValid: true, isAdmin: false };
        }
        
        // 如果您想要更嚴格的驗證，可以查詢資料庫
        // 這裡可以添加從資料庫驗證 token 的邏輯
        
        return { isValid: false, isAdmin: false };
    } catch (error) {
        return { isValid: false, isAdmin: false };
    }
};

// 主要的權限檢查中介軟體 - 基於 actionType 動態檢查權限
const checkActionPermission = async (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader?.replace('Bearer ', '');
    
    // 驗證 token
    const { isValid: isLoggedIn, isAdmin } = await verifyToken(token);
    
    // 定義未登入用戶可以使用的功能
    const guestAllowedActions = ['view', 'share'];
    
    // 定義已登入用戶可以使用的功能
    const userAllowedActions = ['bookmark', 'comment', 'score', 'search', 'view', 'share'];
    
    // 定義管理員額外可以使用的功能
    const adminAllowedActions = [...userAllowedActions, 'admin', 'manage', 'delete', 'edit'];
    
    // 從路由參數取得 actionType
    const actionType = req.params.actionType;
    
    // 檢查權限
    let allowedActions;
    let userType;
    
    if (isLoggedIn) {
        if (isAdmin) {
            allowedActions = adminAllowedActions;
            userType = 'admin';
        } else {
            allowedActions = userAllowedActions;
            userType = 'logged_in';
        }
        req.userPermissions = {
            isLoggedIn: true,
            isAdmin: isAdmin,
            allowedActions: allowedActions
        };
    } else {
        allowedActions = guestAllowedActions;
        userType = 'guest';
        req.userPermissions = {
            isLoggedIn: false,
            isAdmin: false,
            allowedActions: guestAllowedActions
        };
    }
    
    // 如果有指定 actionType，檢查是否有權限
    if (actionType && !allowedActions.includes(actionType)) {
        return res.status(403).json({
            success: false,
            message: '權限不足',
            desc: `需要${isLoggedIn ? (isAdmin ? '管理員' : '更高') : '登入'}權限才能使用 ${actionType} 功能`,
            userType: userType,
            allowedActions: allowedActions,
            requestedAction: actionType
        });
    }
    
    next();
};

// 靜態權限檢查 - 用於特定的權限需求
const checkUserPermission = (requiredActions) => {
    return async (req, res, next) => {
        const authHeader = req.headers['authorization'];
        const token = authHeader?.replace('Bearer ', '');
        
        // 驗證 token
        const { isValid: isLoggedIn, isAdmin } = await verifyToken(token);
        
        // 定義未登入用戶可以使用的功能
        const guestAllowedActions = ['view', 'share'];
        
        // 定義已登入用戶可以使用的功能
        const userAllowedActions = ['bookmark', 'comment', 'score', 'search', 'view', 'share'];
        
        // 定義管理員額外可以使用的功能
        const adminAllowedActions = [...userAllowedActions, 'admin', 'manage', 'delete', 'edit'];
        
        // 如果沒有指定需要的權限，直接通過
        if (!requiredActions || requiredActions.length === 0) {
            return next();
        }
        
        // 檢查權限
        let allowedActions;
        let userType;
        
        if (isLoggedIn) {
            if (isAdmin) {
                allowedActions = adminAllowedActions;
                userType = 'admin';
            } else {
                allowedActions = userAllowedActions;
                userType = 'logged_in';
            }
            req.userPermissions = {
                isLoggedIn: true,
                isAdmin: isAdmin,
                allowedActions: allowedActions
            };
        } else {
            allowedActions = guestAllowedActions;
            userType = 'guest';
            req.userPermissions = {
                isLoggedIn: false,
                isAdmin: false,
                allowedActions: guestAllowedActions
            };
        }
        
        // 檢查是否有權限執行所需的操作
        const hasPermission = requiredActions.every(action => 
            allowedActions.includes(action)
        );
        
        if (!hasPermission) {
            const missingActions = requiredActions.filter(action => 
                !allowedActions.includes(action)
            );
            
            return res.status(403).json({
                success: false,
                message: '權限不足',
                desc: `需要${isLoggedIn ? (isAdmin ? '管理員' : '更高') : '登入'}權限才能使用以下功能: ${missingActions.join(', ')}`,
                userType: userType,
                allowedActions: allowedActions,
                missingActions: missingActions
            });
        }
        
        next();
    };
};

// 新增：專門檢查是否已登入的中介軟體
const requireLogin = async (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader?.replace('Bearer ', '');
    
    const { isValid: isLoggedIn } = await verifyToken(token);
    
    if (!isLoggedIn) {
        return res.status(401).json({
            success: false,
            message: '請先登入',
            desc: '此功能需要登入才能使用',
            userType: 'guest'
        });
    }
    
    // 設置用戶權限資訊
    req.userPermissions = {
        isLoggedIn: true,
        isAdmin: false, // 可以根據需要查詢資料庫
        allowedActions: ['bookmark', 'comment', 'score', 'search', 'view', 'share']
    };
    
    next();
};

// 新增：專門檢查管理員權限的中介軟體
const requireAdmin = async (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader?.replace('Bearer ', '');
    
    const { isValid: isLoggedIn, isAdmin } = await verifyToken(token);
    
    if (!isLoggedIn) {
        return res.status(401).json({
            success: false,
            message: '請先登入',
            desc: '此功能需要登入才能使用',
            userType: 'guest'
        });
    }
    
    if (!isAdmin) {
        return res.status(403).json({
            success: false,
            message: '權限不足',
            desc: '此功能需要管理員權限',
            userType: 'logged_in'
        });
    }
    
    // 設置管理員權限資訊
    req.userPermissions = {
        isLoggedIn: true,
        isAdmin: true,
        allowedActions: ['bookmark', 'comment', 'score', 'search', 'view', 'share', 'admin', 'manage', 'delete', 'edit']
    };
    
    next();
};

// 預定義的權限檢查中介軟體
const permissions = {
    // 主要的動態權限檢查 - 用於用戶行為路由
    checkAction: checkActionPermission,
    
    // 需要登入的功能
    requireLogin: requireLogin,
    
    // 需要管理員權限
    requireAdmin: requireAdmin,
    
    // 特定功能的權限檢查
    bookmark: checkUserPermission(['bookmark']),
    comment: checkUserPermission(['comment']),
    score: checkUserPermission(['score']),
    search: checkUserPermission(['search']),
    
    // 遊客也可以使用的功能
    view: checkUserPermission(['view']),
    share: checkUserPermission(['share']),
    
    // 管理員功能
    admin: checkUserPermission(['admin']),
    manage: checkUserPermission(['manage']),
    delete: checkUserPermission(['delete']),
    edit: checkUserPermission(['edit']),
    
    // 自定義權限檢查
    custom: (actions) => checkUserPermission(actions)
};

// 輔助函數：檢查用戶是否有特定權限
const hasPermission = (req, action) => {
    if (!req.userPermissions) {
        return false;
    }
    return req.userPermissions.allowedActions.includes(action);
};

// 輔助函數：獲取用戶權限資訊
const getUserPermissions = (req) => {
    return req.userPermissions || {
        isLoggedIn: false,
        isAdmin: false,
        allowedActions: ['view', 'share']
    };
};

// 新增：獲取當前用戶權限信息的路由處理器
const getPermissionInfo = async (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader?.replace('Bearer ', '');
    
    const { isValid: isLoggedIn, isAdmin } = await verifyToken(token);
    
    let allowedActions;
    let userType;
    
    if (isLoggedIn) {
        if (isAdmin) {
            allowedActions = ['bookmark', 'comment', 'score', 'search', 'view', 'share', 'admin', 'manage', 'delete', 'edit'];
            userType = 'admin';
        } else {
            allowedActions = ['bookmark', 'comment', 'score', 'search', 'view', 'share'];
            userType = 'logged_in';
        }
    } else {
        allowedActions = ['view', 'share'];
        userType = 'guest';
    }
    
    return res.json({
        success: true,
        message: '權限信息獲取成功',
        data: {
            isLoggedIn: isLoggedIn,
            isAdmin: isAdmin,
            userType: userType,
            allowedActions: allowedActions
        }
    });
};

module.exports = {
    checkUserPermission,
    checkActionPermission,
    permissions,
    hasPermission,
    getUserPermissions,
    requireLogin,
    requireAdmin,
    getPermissionInfo,
    verifyToken
};