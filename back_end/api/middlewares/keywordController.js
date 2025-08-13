const pool = require('../connect_db');
const { checkRequireField } = require('../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');

// search
async function searchKeyword (req, res, next) {
    let text = req.query?.text;

    // 檢查必要欄位 & 格式 - text
    try {
        [ text ] = await checkRequireField ([
            { field: 'text' , data: text , type: 'string' }
        ]);
    } catch (err) {
        err.desc = "middlewares-searchKeyword(): Missing or Invalid required fields";
        return next(err);
    }

    let sql = `
        SELECT * FROM keyword_data
        WHERE 1
    `;
    let params = [];
    if ( text ) {
        sql += " AND keyword_text=?";
        params.push(text);
    }
    try {
        let [result] = await pool.query( sql, params );
        return res.apiSuccess(result, "Search Success");
    } catch (err) {
        err.desc = "middlewares - searchKeyword(): database search error";
        return next(err);
    }
    
}

// insert
async function insertKeyword (req, res, next) {
    let text = req.query?.text;

    // 檢查必要欄位 & 格式 - text
    try {
        [ text ] = await checkRequireField ([
            { field: 'text' , data: text , type: 'string' , other: ['non_null'] }
        ]);
    } catch (err) {
        err.desc = "middlewares-insertKeyword(): Missing or Invalid required fields";
        return next(err);
    }
    
    // 先 search
    let fakeReq = {
        query: { text: text }
    };
    
    let searchKeywordResult = await callAndCatchApiSuccess ( searchKeyword, fakeReq );
    if ( searchKeywordResult.length > 0 ) {
        return res.apiSuccess({ insertId: searchKeywordResult[0].keyword_id }, "Search Success" );
    }

    // 再 insert
    let sql = `
        INSERT INTO keyword_data(keyword_text) VALUE (?)
    `;
    let params = [text];
    try {
        let [result] = await pool.query(sql, params);
        return res.apiSuccess({ insertId: result.insertId }, "Insert Success");
    } catch (err) {
        err.desc = "middlewares - insertKeyword(): database insert error";
        return next(err);
    }
}

// update
async function updateKeyword(req, res, next) {
    return;
}

// delete
async function deleteKeyword(req, res, next) {
    let id = req.params?.id;

    // 檢查必要欄位 & 格式 - id
    try {
        [ id ] = await checkRequireField ([
            { field: 'id' , data: id , type: 'number' , other: ['non_null'] }
        ]);
    } catch (err) {
        err.desc = "middlewares-deleteKeyword(): Missing or Invalid required fields";
        return next(err);
    }

    let sql = `
        DELETE FROM keyword_data
        WHERE keyword_id=?
    `;
    let params = [id];
    try {
        let [result] = await pool.query(sql, params);

        // 如果沒有刪除任何資料
        if (result.affectedRows === 0) {
            let err = new Error('Keyword not found')
            err.desc = 'middlewares-deleteKeyword(): Keyword not found';
            err.status = 404;
            return next(err);
        }

        return res.apiSuccess({}, "Delete Success");
    } catch (err) {
        err.desc = "middlewares-deleteKeyword(): database delete error";
        return next(err);
    }

    
}

module.exports = {
    searchKeyword,
    insertKeyword,
    updateKeyword,
    deleteKeyword
}