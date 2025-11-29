const pool = require('../connect_db');
const { checkRequireField } = require('../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');
const { insertKeyword } = require('./keywordController');
const { searchNews } = require('./newsController');

// general search
async function generalSearch (req, res, next) {
    //let keyword = req.query?.keyword;
    let {userId, keyword} = req.body ?? {}
    const clientIp = req.clientIp;
    try {
        [ keyword, userId ] = await checkRequireField ([
            { field: 'keyword'      , data: keyword     , type: 'array'     , other: ['non_null', 'string_into_array'] , array_filter: "string"              },
            { field: 'userId'       , data: userId      , type: 'number'    , other: ['lth']                    },
            { field: 'clientIp'     , data: clientIp                        , other: ['non_null', 'non_change'] },
        ]);
    } catch (err) {
        err.desc = "middlewares-historyRecord(): Missing or Invalid required fields";
        return next(err);
    }

    // get keywordId
    let keywordId = []
    try {
        for (const keyword_text of keyword) {
            const fakeReq = { query: { text: keyword_text } };
            const insertKeywordResult = await callAndCatchApiSuccess(insertKeyword, fakeReq);
            keywordId.push(insertKeywordResult.insertId);
        }
    } catch (err) {
        err.desc = "middlewares-insertUserAction(): Insert Keyword Error";
        return next(err);
    }

    const cols = `${userId ? 'user_id,' : ''} user_ip, keyword_id`;
    const rowPlaceholder = userId ? '(?, ?, ?)' : '(?, ?)';
    const SQL_VALUES = keywordId.map(() => rowPlaceholder).join(', ');
    sql = `
        INSERT INTO user_search_record (${cols})
        VALUES ${SQL_VALUES}
    `;
    params = [];
    for (const kid of keywordId) {
        if (userId) params.push(userId);
        params.push(clientIp, kid);
    }

    try {
        let [result] = await pool.query(sql, params);
    } catch (err) {
        err.desc = "middlewares-insertUserAction(): database insert error";
        return next(err);
    }
    
    
    let newsList = channelList = eventsortingList = multipleperspectivesList = []

    // ---------- 查找 4 個 dataType , 做成 list 回傳 ----------
    // newsList
    fakeReq = {
        query: { limit: 100 },
        body: { keyword: keyword}
    }
    try {
        let searchNewsResult = await callAndCatchApiSuccess ( searchNews, fakeReq );
        newsList = searchNewsResult.simpleList;
    } catch (err) {
        err.desc = "middlewares-insertUserAction(): Insert Keyword Error";
        return next(err);
    }

    return res.apiSuccess({
        newsList: newsList,
        channelList: channelList,
        eventsortingList: eventsortingList,
        multipleperspectivesList: multipleperspectivesList
    }, "Insert Success");
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
        WHERE usr.user_id = ?
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