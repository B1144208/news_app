const pool = require('../connect_db');
const { checkRequireField } = require('../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');
const { searchAnonymous, insertAnonymous } = require('./anonymousController');
// search
async function searchUserAction (req, res, next) {
    /*
    @ actionType: comment, bookmark
    @ dataType  : news, channel, eventsorting, multipleperspectives
    */
    let { actionType, dataType } = req.params ?? {}
    let { userId } = req.body ?? {}

    // 檢查必要欄位 & 格式 - id
    try {
        [ actionType, dataType, userId ] = await checkRequireField ([
            { field: 'actionType'   , data: actionType  , type: 'string'    , other: ['non_null'],  enum: ['comment', 'bookmark']                                    },
            { field: 'dataType'     , data: dataType    , type: 'string'    , other: ['non_null'],  enum: ['news', 'channel', 'eventsorting','multipleperspectives'] },
            { field: 'userId'       , data: userId      , type: 'number'    , other: ['non_null']                                                                    }
        ]);
    } catch (err) {
        err.desc = "middlewares-searchUserAction(): Missing or Invalid required fields";
        return next(err);
    }

    let sql = `
        SELECT * 
        FROM user_${actionType}
        WHERE user_id=? AND ${dataType}_id IS NOT NULL
    `;
    let params = [ userId ];
    try {
        let [result] = await pool.query(sql, params);
        return res.apiSuccess(result, "Search Success");
    } catch (err) {
        err.desc = "middlewares-searchUserAction(): ";
        return next(err);
    }
}

// insert
async function insertUserAction (req, res, next) {
    /*
    @ actionType : view, comment, bookmark, share, score
    @ dataType   : news, channel, eventsorting, multipleperspectives
    @ comment    : anonymous(可空), text
    @ score      : score
    */
    let { actionType, dataType } = req.params ?? {}
    let { userId, dataId, clientIp } = req.body ?? {}
    let { anonymous, text, score } = req.body ?? {}

    // 檢查必要欄位 & 格式 - actionType, dataType, userId, dataId, clientIp, anonymous, text, score
    try {
        [ actionType, dataType, userId, dataId, anonymous, text, score ] = await checkRequireField ([
            { field: 'actionType'   , data: actionType  , type: 'string'    , other: ['non_null'],  enum: ['view', 'comment', 'bookmark', 'share', 'score']          },
            { field: 'dataType'     , data: dataType    , type: 'string'    , other: ['non_null'],  enum: ['news', 'channel', 'eventsorting','multipleperspectives'] },
            { field: 'userId'       , data: userId      , type: 'number'    , other: ['lth']                    },
            { field: 'dataId'       , data: dataId      , type: 'number'    , other: ['non_null']               },
            { field: 'clientIp'     , data: clientIp                        , other: ['non_null', 'non_change'] },
            { field: 'anonymous'    , data: anonymous   , type: 'string'    , other: ['lth']                    },
            { field: 'text'         , data: text        , type: 'string'    , other: ['lth']                    },
            { field: 'score'        , data: score       , type: 'number'    , other: ['lth']                    }
        ]);
    } catch (err) {
        err.desc = "middlewares-insertUserAction(): Missing or Invalid required fields";
        return next(err);
    }

    // view & share 才能使用 clientIp
    let invalidField = false;
    invalidField = ( (!userId)? !actionType==='view' && !actionType==='share': false ) ||
                   ( (actionType === 'comment')? !text : false ) ||
                   ( (actionType === 'score')? !score : false )
    if ( invalidField ) {
        err = new Error("Missing or Invalid required fields");
        err.desc = "middlewares-insertUserAction(): Missing or Invalid required fields";
        return next(err);
    }

    let sql = `
        INSERT INTO user_${actionType} ( user_${userId? 'id': 'ip'}, ${dataType}_id )
        VALUES ( ?, ? )
    `;
    let params = [ userId || clientIp, dataId ];

     
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
        sql = `
            INSERT INTO user_${actionType} ( user_${userId? 'id': 'ip'}, ${dataType}_id, anonymous_id, comment_text )
            VALUES ( ?, ? , ?, ?)
        `;
        params.push( anonymousId, text );
    }

    if (actionType==="score") {
        sql = `
            INSERT INTO user_${actionType} ( user_${userId? 'id': 'ip'}, ${dataType}_id, target_score )
            VALUES ( ?, ? , ?)
        `;
        params.push( score );
    }

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
    @ actionType : comment, bookmark, score
    @ targetId   : actionType 的 id
    @ comment    : anonymous(可空), text
    @ bookmark   : groupcustomizeId(可空)
    @ score      : score
    */
    let { actionType, targetId } = req.params ?? {}
    let { anonymous, text, groupcustomizeId, score } = req.body ?? {}

    // 檢查必要欄位 & 格式 - id
    try {
        [ actionType, targetId, anonymous, text, groupcustomizeId, score ] = await checkRequireField ([
            { field: 'actionType'       , data: actionType      , type: 'string'    , other: ['non_null'], enum: ['comment', 'bookmark', 'score']   },
            { field: 'targetId'         , data: targetId        , type: 'number'    , other: ['non_null']   },
            { field: 'anonymous'        , data: anonymous       , type: 'string'    , other: ['lth']        },
            { field: 'text'             , data: text            , type: 'string'    , other: ['lth']        },
            { field: 'groupcustomizeId' , data: groupcustomizeId, type: 'number'    , other: ['lth']        },
            { field: 'score'            , data: score           , type: 'number'    , other: ['lth']        }
        ]);
    } catch (err) {
        err.desc = "middlewares-updateUserAction(): Missing or Invalid required fields";
        return next(err);
    }

    let invalidField = false;
    invalidField = ( (actionType === 'comment')? !text : false ) ||
                   ( (actionType === 'score')? !score : false )
    if ( invalidField ) {
        err = new Error("Missing or Invalid required fields");
        err.desc = "middlewares-updateUserAction(): Missing or Invalid required fields";
        return next(err);
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
    @ actionType : comment, bookmark, score
    @ targetId   : actionType 的 id
    */
    let { actionType, targetId } = req.params ?? {}

    // 檢查必要欄位 & 格式 - id
    try {
        [ actionType, targetId, anonymous, text, groupcustomizeId, score ] = await checkRequireField ([
            { field: 'actionType'       , data: actionType      , type: 'string'    , other: ['non_null'],  enum: ['comment', 'bookmark', 'score']  },
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

module.exports = {
    searchUserAction,
    insertUserAction,
    updateUserAction,
    deleteUserAction
}