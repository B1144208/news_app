const pool = require('../connect_db');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');

// search
async function searchKeyword (req, res, next) {
    let text = req.query.text;
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
    let text = req.query.text;

    // 檢查 text
    if (!text || typeof text !== 'string' || text.trim() === '') {
        const err = new Error("Invalid text format");
        err.desc = "middlewares - insertRelation(): Invalid Format - ( text )";
        err.status = 400;
        return next(err);
    }
    
    // 先 search
    let fakeReq = {
        query: {
            text: text
        }
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
    const id = req.params.id;

    // 檢查 id 是否有效
    if (!id || isNaN(id)) {
        let err = new Error('Invalid Number Error');
        err.desc = 'middlewares-deleteKeyword(): Missing or Invalid required fields - keyword_id';
        err.status = 400;
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