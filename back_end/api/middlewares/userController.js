const pool = require('../connect_db');
const { checkRequireField } = require('../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');
const { checkPassword, hashPassword } = require('../utils/passwordHelper');
const { generateUsername } = require('../utils/randomHelper');
const { insertGroupcustomize } = require('./groupcustomizeController');

// search
async function searchUser (req, res, next) {
    /*
    @ 無 id            : 查全部
    @ 有 id            : 查 user_id
    @ 無 id 有 account : 查 account 的 user_id
    @ 有 login         : 查 account 的 user_id, 並 next() 給 checkPassword
    */
    let id = req.params?.id;
    const login = req.originalUrl.includes('/login');
    const { account, password } = req.body ?? {};

    // 檢查必要欄位 & 格式 - id
    try {
        requireFields = [ { field: 'id'   , data: id  , type: 'number' } ];

        ( !login && account ) && requireFields.push (
            { field: 'account' , data: account , type: 'string' , other: ['non_null', 'non_change'] }
        );

        login && requireFields.push(
            { field: 'account'  , data: account  , type: 'string' , other: ['non_null', 'non_change'] },
            { field: 'password' , data: password , type: 'string' , other: ['non_null', 'non_change'] },
        );

        [ id ] = await checkRequireField ( requireFields );

    } catch (err) {
        err.desc = "middlewares-searchUser(): Missing or Invalid required fields";
        return next(err);
    }

    // general search
    let sql = `
        SELECT *
        FROM user_profile
        WHERE 1
    `
    params = [];

    // id search
    if ( id ) {
        sql += " AND user_id=?";
        params.push ( id );
    }
    // account search
    else if ( account ) {
        sql += " AND user_account=?";
        params.push ( account );
    }

    try {
        let [result] = await pool.query( sql, params );
        let user_id = null;
        let hashedPassword = null;
        
        if (result.length === 1) {
            user_id = result[0].user_id;  // 直接賦值，不用 && 運算符
            hashedPassword = result[0].user_password;
        }

        if ( login ) {
            if ( result.length === 1 ) {
                try {
                    let fakeReq = {
                        password: { plainPassword: password, hashedPassword: hashedPassword }
                    };
                    let checkResult = await callAndCatchApiSuccess ( checkPassword, fakeReq );
                    
                    // 確保返回正確的 userId
                    return res.apiSuccess ( { 
                        success: checkResult.success, 
                        userId: user_id  // 使用實際的 user_id 值
                    }, (checkResult.success) ? "Enter Correct" : "Password Error");
                    
                } catch (err) {
                    err.desc = "middlewares-searchUser(): checkPassword error";
                    return next(err);
                }
            } else {
                return res.apiSuccess ( { success: false }, "Account Error" );
            }
        }
        return res.apiSuccess( result, "Search Success");
    } catch (err) {
        err.desc = "middlewares-searchUser(): database search error";
        return next(err);
    }
}

// insert
async function insertUser (req, res, next) {

    const { account, password } = req.body ?? {};
    let hashedPassword;

    // 檢查必要欄位 & 格式 - account, password
    try {
        let [ result] = await checkRequireField ([
            { field: 'account'  , data: account     , type: 'string'    , other: ['non_null', 'non_change'] },
            { field: 'password' , data: password    , type: 'string'    , other: ['non_null', 'non_change'] }
        ]);
    } catch (err) {
        err.desc = "middlewares-insertUser(): Missing or Invalid required fields";
        return next(err);
    }

    try {
        let fakeReq = {
            password: { plainPassword: password }
        };
        let result = await callAndCatchApiSuccess ( hashPassword, fakeReq );
        hashedPassword = result.hashedPassword;
    } catch (err) {
        err.desc = "middlewares-insertUser(): hashPassword error";
        return next(err);
    }

    let sql = `
        INSERT INTO user_profile ( user_account, user_password, user_name )
        VALUES ( ?, ?, ?)
    `
    let params = [ account, hashedPassword, generateUsername() ];
    let userId;
    try {
        let [result] = await pool.query( sql, params);
        userId = result.insertId;
    } catch (err) {
        err.desc = "middlewares-insertUser(): database insert error";
        return next(err);
    }

    // insert groupcustomize order
    let fakeReq = {
        params: { kind: "general" },
        body: {userId: userId}
    };
    try {
        let insertGroupcustomizeResult = callAndCatchApiSuccess(insertGroupcustomize, fakeReq);
        return res.apiSuccess ( { insertId: userId }, "Insert Success");
    } catch (err) {
        err.desc = "middlewares-insertUser(): database groupcustomize insert error";
        return next(err);
    }
}


// update
async function updateUser(req, res, next) {
    const { user_id, location_country_id } = req.body ?? {};


    // 🚨 暫時跳過 checkRequireField，直接檢查關鍵字段 🚨
    if (!user_id || typeof user_id !== 'number') {
        // 如果 user_id 不是數字，嘗試轉換它 (因為前端可能傳遞數字型字串)
        const parsedUserId = parseInt(user_id);
        if (isNaN(parsedUserId)) {
            const err = new Error("User ID is missing or invalid.");
            err.status = 400;
            err.desc = "middlewares-updateUser(): User ID check failed";
            return next(err);
        }
    }

    // 如果 location_country_id 是 'null' 或空字串，將其設為 null (用於資料庫)
    const countryIdToUpdate = (location_country_id === 'null' || location_country_id === '') ? null : location_country_id;

    let sql = `
        UPDATE user_profile
        SET location_country_id = ?
        WHERE user_id = ?
    `;
    let params = [ countryIdToUpdate, user_id ];


    try {
        let [result] = await pool.query( sql, params );


        if (result.affectedRows === 0) {
            // 如果影響行數為 0，通常是 user_id 不存在，或新舊值相同
            return res.apiSuccess(
                { updated: false, user_id: user_id, affectedRows: 0, changedRows: 0 },
                "Update Failed: User ID not found or Location is already set to this value."
            );
        }

        return res.apiSuccess(
            { updated: true, user_id: user_id, affectedRows: result.affectedRows, changedRows: result.changedRows },
            "Update Success"
        );
    } catch (err) {
        // 🌟 捕捉任何資料庫錯誤並記錄 🌟
        err.desc = "middlewares-updateUser(): database update error";
        console.error("DATABASE ERROR:", err);
        return next(err);
    }
}

// delete
async function deleteUser(req, res, next) {
    return;
}

module.exports = {
    searchUser,
    insertUser,
    updateUser,
    deleteUser
}