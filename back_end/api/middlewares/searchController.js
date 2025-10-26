const pool = require('../connect_db');
const { checkRequireField } = require('../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');
const { insertKeyword } = require('./keywordController');

// general search
async function generalSearch (req, res, next) {
    let keyword = req.query?.keyword;
    let userId = req.body?.userId
    const clientIp = req.clientIp;
    try {
        [ keyword, userId ] = await checkRequireField ([
            { field: 'keyword'      , data: keyword     , type: 'string'    , other: ['non_null']               },
            { field: 'userId'       , data: userId      , type: 'number'    , other: ['lth']                    },
            { field: 'clientIp'     , data: clientIp                        , other: ['non_null', 'non_change'] },
        ]);
    } catch (err) {
        err.desc = "middlewares-historyRecord(): Missing or Invalid required fields";
        return next(err);
    }

    // get keywordId
    let keywordId = null
    let fakeReq = {
        query: { text: keyword }
    }
    try {
        let insertKeywordResult = await callAndCatchApiSuccess ( insertKeyword, fakeReq );
        keywordId = insertKeywordResult.insertId;
    } catch (err) {
        err.desc = "middlewares-insertUserAction(): Insert Keyword Error";
        return next(err);
    }

    // get recordId
    let recordId = null, hasRecord = false;
    let sql = `
        SELECT * 
        FROM user_search_record 
        WHERE user_id = ? AND keyword_id = ?
    `;
    let params = [userId, keywordId];
    try {
        let [result] = await pool.query(sql, params);
        hasRecord = (result.length != 0) && ( recordIncrease(userId, keywordId) ) && (recordId = result[0]["record_id"])
    } catch (err) {
        err.desc = "middlewares-insertUserAction(): database insert error";
        return next(err);
    }

    if ( !hasRecord ) {
        sql = `
                INSERT INTO user_search_record (
                    ${userId? "user_id,": ""}
                    user_ip,
                    keyword_id
                ) VALUES ( ${userId? "?,": ""} ?, ? )
            `;
            params = [];
            if (userId) params.push(userId);
            params.push(clientIp, keywordId);
            try {
                let [result] = await pool.query(sql, params);
                recordId = result.insertId;
            } catch (err) {
                err.desc = "middlewares-insertUserAction(): database insert error";
                return next(err);
            }
    }
    
    let newsList = channelList = eventsortingList = multipleperspectivesList = []

    // ---------- 查找 4 個 dataType , 做成 list 回傳 -------------------------------------------------------------------------------------

    return res.apiSuccess({
        insertId: recordId,
        newsList: newsList,
        channelList: channelList,
        eventsortingList: eventsortingList,
        multipleperspectivesList: multipleperspectivesList
    }, "Insert Success");
}

async function recordIncrease ( userId, keywordId, increase = 1 ) {
    let sql = `
        UPDATE user_search_record
        SET search_counts=search_counts + ?
        WHERE user_id = ? AND keyword_id = ?
    `;
    let params = [ increase, userId, keywordId ];
    try {
        let [result] = await pool.query(sql, params);
        return;
    } catch (err) {
        err.desc = "middlewares-recordIncrease(): database increase error";
        return next(err);
    }
}

// other search
async function historyRecord (req, res, next) {
    let userId = req.params?.userId;
    try {
        [ userId ] = await checkRequireField ([
            { field: 'userId' , data: userId , type: 'number' , other: ['lth'] }
        ]);
    } catch (err) {
        err.desc = "middlewares-historyRecord(): Missing or Invalid required fields";
        return next(err);
    }

    sql = `
        SELECT DISTINCT kd.keyword_id, kd.keyword_text
        FROM user_search_record AS usr
        JOIN keyword_data AS kd ON kd.keyword_id = usr.keyword_id
        WHERE usr.user_id = 1
        ORDER BY kd.keyword_id DESC
        LIMIT 10;
    `;
    params = [userId];
    try {
        let [result] = await pool.query(sql, params);
        return res.apiSuccess(result, 'Search Success');
    } catch (err) {
        err.desc = "middlewares-historyRecord(): database search error";
        return next(err);
    }
}

async function popularSearch (req, res, next) {
    sql = `
        SELECT 
            kd.keyword_id, 
            kd.keyword_text
        FROM keyword_data AS kd
        JOIN keyword_relation AS kr 
            ON kd.keyword_relation_id = kr.keyword_relation_id
        WHERE (kd.keyword_relation_id, kd.total_search_heat) IN (
            SELECT 
                keyword_relation_id, 
                MAX(total_search_heat)
            FROM keyword_data
            GROUP BY keyword_relation_id
        )
        ORDER BY kr.total_search_heat DESC, kd.total_search_heat DESC
        LIMIT 10;
    `;
    params = [];
    try {
        let [result] = await pool.query(sql, params);
        return res.apiSuccess(result, "Search Success");
    } catch (err) {
        err.desc = "middlewares-popularSearch(): database search error";
        return next(err);
    }
}


module.exports = {
    generalSearch,
    historyRecord,
    popularSearch
}