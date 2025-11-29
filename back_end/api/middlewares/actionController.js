const pool = require('../connect_db');
const { checkRequireField } = require('../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');
const { searchAnonymous, insertAnonymous } = require('./anonymousController');
const { insertKeyword } = require('./keywordController');

// search
async function searchUserAction (req, res, next) {
    /*
    @ actionType: bookmark, comment, score, location
    @ dataType  : news, channel, eventsorting, multipleperspectives
    */
    let { actionType, dataType } = req.params ?? {}
    let { userId, dataId } = req.query ?? {}

    let sql;
    let params;

    // 檢查必要欄位 & 格式 - id

    try {
        [ actionType, dataType ] = await checkRequireField ([
            { field: 'actionType'   , data: actionType  , type: 'string'    , other: ['non_null'],  enum: ['bookmark', 'comment', 'score', 'location'] },
            { field: 'dataType'     , data: dataType    , type: 'string'    , other: ['non_null'],  enum: ['news', 'channel', 'eventsorting','multipleperspectives'] }
        ]);
    } catch (err) {
        err.desc = "middlewares-searchUserAction(): Missing or Invalid required fields";
        return next(err);
    }


    //  COMMENT 查詢

    if (actionType==="comment") {
        const dataIdFieldName = `${dataType}_id`;

        let sql = `
            SELECT
                t1.comment_id,
                t1.user_id,
                t1.comment_text,
                t1.created_at,
                t2.anonymous_name,  /* 匿名名稱 */
                t3.user_name        /* 來自 user_profile 的真實用戶名稱 */
            FROM user_comment t1
            LEFT JOIN anonymous_data t2 ON t1.anonymous_id = t2.anonymous_id
            LEFT JOIN user_profile t3 ON t1.user_id = t3.user_id  /* 🌟 使用正確的表名 user_profile 🌟 */
            WHERE t1.${dataIdFieldName} = ?
            ORDER BY t1.created_at DESC
        `;
        let params = [ dataId ];

        try {
            let [result] = await pool.query(sql, params);

            // 格式化結果：決定顯示哪個名稱
            const commentsWithNames = result.map(comment => {
                let displayUser;
                if (comment.anonymous_name) {
                    displayUser = comment.anonymous_name; // 使用匿名名稱
                } else if (comment.user_name) {
                    displayUser = comment.user_name;     // 使用真實用戶名稱
                } else if (comment.user_id) {
                    displayUser = `用戶 #${comment.user_id}`; // Fallback 到 ID
                } else {
                    displayUser = '訪客';
                }

                return {
                    ...comment,
                    display_name: displayUser,
                    is_anonymous: !!comment.anonymous_name,
                };
            });

            return res.apiSuccess(commentsWithNames, "Search Success");
        } catch (err) {
            err.desc = "middlewares-searchUserAction(): database search error for comment";
            return next(err);
        }
    }



    // 非 comment 的動作才需要檢查 userId
    try {
        [ userId ] = await checkRequireField ([
            { field: 'userId'       , data: userId      , type: 'number'    , other: ['non_null'] }
        ]);
    } catch (err) {
        err.desc = "middlewares-searchUserAction(): Missing or Invalid required userId for non-comment actions";
        return next(err);
    }


    // 特殊处理 location 查询 (原結構保留)
    if (actionType === 'location') {
        let sql = `
                SELECT ul.*
                FROM user_location ul
                WHERE ul.user_id = ?
            `;
        let params = [ userId ];
        try {
            let [result] = await pool.query(sql, params);
            return res.apiSuccess(result, "Search Location Success");
        } catch (err) {
            err.desc = "middlewares-searchUserAction(): location search error";
            return next(err);
        }
    }

    sql = `
        SELECT *
        FROM user_${actionType}
        WHERE user_id=? AND ${dataType}_id IS NOT NULL
    `;
    params = [ userId ];
    try {
        let [result] = await pool.query(sql, params);
        return res.apiSuccess(result, "Search Success");
    } catch (err) {
        err.desc = "middlewares-searchUserAction(): database search error for other actions";
        return next(err);
    }
}

// insert
async function insertUserAction (req, res, next) {
    /*
    @ actionType : view, share, search, bookmark, comment, score, location
    @ dataType   : news, channel, eventsorting, multipleperspectives
    @ comment    : anonymous(可空), text
    @ score      : score
    @ location   : region_id, country_id, state_id
    */
    let { actionType, dataType } = req.params ?? {}
    let { userId, dataId } = req.body ?? {}
    let { anonymous, text, score, region_id, country_id, state_id } = req.body ?? {}
    const clientIp = req.clientIp;

    // 如果 actionType 是 'location'，則 dataId 可以是 'lth' (可選)；否則必須是 'non_null'
    const dataIdCheck = (actionType === 'location') ? ['lth'] : ['non_null'];

    if (actionType === 'location') {
        // 檢查 region_id, country_id, state_id 是否至少有一個存在
        if (region_id === null && country_id === null && state_id === null) {
            // 如果三個 ID 都是空的，則視為無效請求，拋出錯誤
            const error = new Error('Missing or Invalid required fields');
            error.desc = 'middlewares-insertUserAction(): actionType=location requires at least one ID (region_id, country_id, or state_id).';
            throw error; // 拋出錯誤，阻止程式繼續執行
        }
    }

    // 檢查必要欄位 & 格式 - actionType, dataType, userId, dataId, clientIp, anonymous, text, score
    try {
        [ actionType, dataType, userId, dataId, anonymous, text, score, region_id, country_id, state_id ] = await checkRequireField ([
            { field: 'actionType'   , data: actionType  , type: 'string'    , other: ['non_null'], enum: ['view', 'share', 'search', 'bookmark', 'comment', 'score', 'location'] },
            { field: 'dataType'     , data: dataType    , type: 'string'    , other: ['non_null'], enum: ['news', 'channel', 'eventsorting','multipleperspectives'] },
            { field: 'userId'       , data: userId      , type: 'number'    , other: ['lth']                    },
            { field: 'dataId'       , data: dataId      , type: 'number'    , other: dataIdCheck                },
            { field: 'anonymous'    , data: anonymous   , type: 'string'    , other: ['lth']                    },
            { field: 'text'         , data: text        , type: 'string'    , other: ['lth']                    },
            { field: 'score'        , data: score       , type: 'number'    , other: ['lth']                    },
            { field: 'region_id'    , data: region_id   , type: 'number'    , other: ['lth']                    },
            { field: 'country_id'   , data: country_id  , type: 'number'    , other: ['lth']                    },
            { field: 'state_id'     , data: state_id    , type: 'number'    , other: ['lth']                    },
            { field: 'clientIp'     , data: clientIp                        , other: ['non_null', 'non_change'] }
        ]);
    } catch (err) {
        err.desc = "middlewares-insertUserAction(): Missing or Invalid required fields";
        return next(err);
    }

    // 僅 view & share 可使用 userId || userIp , search 不能有 userId
    let invalidField = false;
    invalidField = ( (!userId)? !actionType==='view' && !actionType==='share' && !actionType==='search': false ) ||
                   ( (actionType === 'search')? userId : false ) ||
                   ( (actionType === 'comment')? !text : false ) ||
                   ( (actionType === 'score')? !score : false )
    if ( invalidField ) {
        err = new Error("Missing or Invalid required fields");
        err.desc = "middlewares-insertUserAction(): Missing or Invalid required fields";
        return next(err);
    }

    if ( score && ( score <=0 || score>5 ) ) {
        err = new Error("Missing or Invalid required fields");
        err.desc = "middlewares-insertUserAction(): score need to range in (1, 5)";
        return next(err);
    }

    // **************************************************************************************************************
    // 特殊處理 location 插入
    if (actionType === 'location') {
        let checkSql = `SELECT * FROM user_location WHERE user_id = ?`;
        try {
            let [existing] = await pool.query(checkSql, [userId]);

            // 🌟 核心修改 🌟: 使用輔助函式構造 SET 語句和參數
            const { setClause, params: idParams } = getIDSetClause(region_id, country_id, state_id);

            let sql, params;

            if (existing.length > 0) {
                // 更新现有記錄
                sql = `
                    UPDATE user_location
                    SET ${setClause}, updated_at = NOW()
                    WHERE user_id = ?
                `;
                params = [...idParams, userId]; // ID 參數 + userId
            } else {
                // 插入新記錄
                // 這裡需要特別處理，因為 INSERT 語句需要所有欄位名稱
                // 由於我們只確定哪個 ID 有值，需要更精確的 INSERT 語句。

                // 簡化處理：為了避免複雜的動態 INSERT，我們將 NULL ID 設置為 NULL
                sql = `
                    INSERT INTO user_location (user_id, region_id, country_id, state_id, updated_at)
                    VALUES (?, ?, ?, ?, NOW())
                `;
                // 這裡我們直接使用 checkRequireField 之後的參數，它們會是 (1, null, null, 123)
                params = [userId, region_id, country_id, state_id];
            }

            // 由於 INSERT 語句 (上面的 else 塊) 會將三個 ID 都設為參數，
            // 只有 UPDATE 語句需要動態 SET 子句。

            // 重新整理邏輯：如果使用 UPDATE，則使用動態 SET
            if (existing.length > 0) {
                // 🌟 替換 INSERT 之前的 UPDATE 邏輯 🌟
                sql = `
                    UPDATE user_location
                    SET ${setClause}, updated_at = NOW()
                    WHERE user_id = ?
                `;
                params = [...idParams, userId];
            } else {
                sql = `
                    INSERT INTO user_location (user_id, region_id, country_id, state_id, updated_at)
                    VALUES (?, ?, ?, ?, NOW())
                `;
                params = [userId, region_id, country_id, state_id];
            }

            // 檢查：如果錯誤發生在 UPDATE（即 existing.length > 0），則上面的 setClause 修復是正確的。

            let [result] = await pool.query(sql, params);
            return res.apiSuccess({insertId: result.insertId || existing[0].location_id}, "Location Insert/Update Success");
        } catch (err) {
            err.desc = "middlewares-insertUserAction(): location insert/update error";
            // 錯誤訊息就在這裡拋出，說明 SQL 語句有問題。
            return next(err);
        }
    }

    let colums = [ `${dataType}_id` ];
    let params = [ dataId ];
    let needIp = actionType=="view" || actionType=="share";
    if (userId) { colums.push("user_id"); params.push(userId); }
    if (needIp) { colums.push("user_ip"); params.push(clientIp); }

    if (actionType==="comment") {
        let anonymousId = null;
        if ( anonymous ) {
            let fakeReq = {
                query: { name: anonymous }
            }
            try {
                let insertAnonymousResult = await callAndCatchApiSuccess ( insertAnonymous, fakeReq );
                anonymousId = insertAnonymousResult.insertId;
            } catch (err) {
                err.desc = "middlewares-insertUserAction(): Insert Anonymous Error";
                return next(err);
            }
        }
        colums.push("anonymous_id", "comment_text");
        params.push( anonymousId, text );
    }

    if (actionType==="score") {
        colums.push("target_score")
        params.push( score );
    }
    sql = `
        INSERT INTO user_${actionType} (
            ${colums.join(', ')}
        ) VALUES ( ${colums.map(()=>'?').join(', ')} )
    `;


    try {
        let [result] = await pool.query(sql, params);
        return res.apiSuccess({insertId: result.insertId}, "Insert Success");
    } catch (err) {
        err.desc = "middlewares-insertUserAction(): database insert error";
        return next(err);
    }
}

// update
async function updateUserAction(req, res, next) {
    /*
    @ actionType : comment, bookmark, score, location
    @ targetId   : actionType 的 id
    @ comment    : anonymous(可空), text
    @ bookmark   : groupcustomizeId(可空)
    @ score      : score
    @ location   : region_id, country_id, state_id
    */
    let { actionType, targetId } = req.params ?? {}
    let { anonymous, text, groupcustomizeId, score, region_id, country_id, state_id } = req.body ?? {}

    // 檢查必要欄位 & 格式 - id
    try {
        [ actionType, targetId, anonymous, text, groupcustomizeId, score, region_id, country_id, state_id ] = await checkRequireField ([
            { field: 'actionType'       , data: actionType      , type: 'string'    , other: ['non_null'], enum: ['comment', 'bookmark', 'score', 'location'] },
            { field: 'targetId'         , data: targetId        , type: 'number'    , other: ['non_null']   },
            { field: 'anonymous'        , data: anonymous       , type: 'string'    , other: ['lth']        },
            { field: 'text'             , data: text            , type: 'string'    , other: ['lth']        },
            { field: 'groupcustomizeId' , data: groupcustomizeId, type: 'number'    , other: ['lth']        },
            { field: 'score'            , data: score           , type: 'number'    , other: ['lth']        },
            { field: 'region_id'        , data: region_id       , type: 'number'    , other: ['lth']        },
            { field: 'country_id'       , data: country_id      , type: 'number'    , other: ['lth']        },
            { field: 'state_id'         , data: state_id        , type: 'number'    , other: ['lth']        }
        ]);
    } catch (err) {
        err.desc = "middlewares-updateUserAction(): Missing or Invalid required fields";
        return next(err);
    }

    let invalidField = false;
    invalidField = ( (actionType === 'comment')? !text : false ) ||
                   ( (actionType === 'score')? !score : false ) ||
                   ( (actionType === 'location')? !region_id && !country_id && !state_id : false )
    if ( invalidField ) {
        err = new Error("Missing or Invalid required fields");
        err.desc = "middlewares-updateUserAction(): Missing or Invalid required fields";
        return next(err);
    }

     // 特殊處理 location 更新
        if (actionType === 'location') {

            // 🌟 核心修改 🌟: 使用輔助函式構造 SET 語句和參數
            const { setClause, params: idParams } = getIDSetClause(region_id, country_id, state_id);

            let sql = `
                UPDATE user_location
                SET ${setClause}, updated_at = NOW()
                WHERE location_id = ?
            `;
            let params = [...idParams, targetId]; // ID 參數 + targetId

            try {
                let [result] = await pool.query(sql, params);
                if (result.affectedRows===1)
                    return res.apiSuccess({sucess: true}, "Location Update Success");
                return res.apiSuccess({sucess: false}, "Location Update Fail");
            } catch (err) {
                err.desc = "middlewares-updateUserAction(): location update error";
                return next(err);
            }
        }

    let sql = `
        UPDATE user_${actionType}
    `;
    let params = [];

    if ( actionType==='comment' ) {
        let anonymousId = null;
        if ( anonymous ) {
            let fakeReq = {
                query: { name: anonymous }
            }
            try {
                let insertAnonymousResult = await callAndCatchApiSuccess ( insertAnonymous, fakeReq );
                anonymousId = insertAnonymousResult.insertId;
            } catch (err) {
                err.desc = "middlewares-updateUserAction(): Insert Anonymous Error";
                return next(err);
            }
        }
        sql += `
            SET anonymous_id = ?,
                comment_text = ?
        `;
        params.push( anonymousId, text );
    }
    if ( actionType==='bookmark' ) {
        sql += `
            SET groupcustomize_id = ?
        `;
        params.push( groupcustomizeId );
    }
    if ( actionType==='score' ) {
        sql += `
            SET target_score = ?
        `;
        params.push( score );
    }
    sql += `
        WHERE ${actionType}_id = ?
    `;
    params.push( targetId );

    try {
        let [result] = await pool.query(sql, params);
        if (result.affectedRows===1)
            return res.apiSuccess({sucess: true}, "Update Success");
        return res.apiSuccess({sucess: false}, "Update Fail");
    } catch (err) {
        err.desc = "middlewares-updateUserAction(): database update error";
        return next(err);
    }
}

// delete
async function deleteUserAction(req, res, next) {
    /*
    @ actionType : comment, bookmark, score, location
    @ targetId   : actionType 的 id
    */
    let { actionType, targetId } = req.params ?? {}

    // 檢查必要欄位 & 格式 - id
    try {
        [ actionType, targetId ] = await checkRequireField ([
            { field: 'actionType'       , data: actionType      , type: 'string'    , other: ['non_null'],  enum: ['comment', 'bookmark', 'score', 'location'] },
            { field: 'targetId'         , data: targetId        , type: 'number'    , other: ['non_null']   }
        ]);
    } catch (err) {
        err.desc = "middlewares-deleteUserAction(): Missing or Invalid required fields";
        return next(err);
    }

    let sql = `
        DELETE FROM user_${actionType}
        WHERE ${actionType}_id = ?
    `;
    let params = [targetId];

    // 特殊处理 location 删除
    if (actionType === 'location') {
        sql = `DELETE FROM user_location WHERE location_id = ?`;
    }

    try {
        let [result] = await pool.query(sql, params);
        if (result.affectedRows===1) 
            return res.apiSuccess({sucess: true}, "Delete Success");
        return res.apiSuccess({sucess: false}, "Delete Fail");
    } catch (err) {
        err.desc = "middlewares-deleteUserAction(): database delete error";
        return next(err);
    }
}

function getIDSetClause(region_id, country_id, state_id) {
    let setClause = '';
    let params = [];

    // 優先順序：state > country > region (理論上只會有一個非空，但這樣寫更安全)
    if (state_id > 0) {
        setClause = 'state_id = ?, country_id = NULL, region_id = NULL';
        params.push(state_id);
    } else if (country_id > 0) {
        setClause = 'country_id = ?, region_id = NULL, state_id = NULL';
        params.push(country_id);
    } else if (region_id > 0) {
        setClause = 'region_id = ?, country_id = NULL, state_id = NULL';
        params.push(region_id);
    } else {
        // 如果三個都是 null，則拋出錯誤（雖然前面已經驗證過，這裡是最終防線）
        const error = new Error('Exactly one of region_id, country_id, state_id must be NOT NULL');
        error.desc = 'Database constraint error: No valid location ID found for SQL generation.';
        throw error;
    }
    return { setClause, params };
}

module.exports = {
    searchUserAction,
    insertUserAction,
    updateUserAction,
    deleteUserAction
}