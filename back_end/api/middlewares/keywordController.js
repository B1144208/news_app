const pool = require('../connect_db');
const { checkRequireField } = require('../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');

// search
async function searchKeyword (req, res, next) {
    let text = req.query?.text;
    const relation = req.query?.relation !== undefined;

    // 檢查必要欄位 & 格式 - text
    try {
        
        [ text ] = relation
            ? await checkRequireField ([
                { field: 'text' , data: text , type: 'string' , other: ['non_null']}
            ])
            : await checkRequireField ([
                { field: 'text' , data: text , type: 'string' }
            ])

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
        sql += " AND keyword_text LIKE ?";
        relation
            ? params.push(`%${text}%`)
            : params.push(text)
    }
    try {
        let [result] = await pool.query( sql, params );

        if ( relation ) {
            if ( result.length === 0) {
                return res.apiSuccess({ success: false }, "Search Fail");
            } else {
                return res.apiSuccess({ success: true, searchId: result[0].keyword_relation_id }, "Search Success");
            }
        }

        return res.apiSuccess(result, "Search Success");
    } catch (err) {
        err.desc = "middlewares - searchKeyword(): database search error";
        return next(err);
    }
    
}

// insert
async function insertKeyword (req, res, next) {
    let text = req.query?.text;
    const relation = req.query?.relation !== undefined;
    
    // insert keyword_relation
    if ( relation ) {

        let sql =  `
            INSERT INTO keyword_relation ()
            VALUES ()
        `;
        let params = [];
        try {
            let [result] = await pool.query(sql, params);
            return res.apiSuccess ({ insertId: result.insertId }, "Insert Success");
        } catch (err) {
            err.desc = "middlewares-insertKeyword(): database insert error ( relation )";
            return next(err);
        }
        
    }

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
    try {
        let searchKeywordResult = await callAndCatchApiSuccess ( searchKeyword, fakeReq );
        if ( searchKeywordResult.length > 0 ) {
            return res.apiSuccess({ insertId: searchKeywordResult[0].keyword_id }, "Search Success" );
        }
    } catch (err) {
        err.desc = "middlewares-insertKeyword(): Search keyword error";
        return next(err);
    }

    // 再 insert
    // 先 search keyword_relation_id
    let keyword_relation_id = null;
    fakeReq = {
        query: { text: text , relation:'' }
    };
    try {
        let searchKeywordRelationResult = await callAndCatchApiSuccess ( searchKeyword, fakeReq );
        if ( searchKeywordRelationResult.success ) {
            keyword_relation_id = searchKeywordRelationResult.searchId;
        }
    } catch (err) {
        err.desc = "middlewares-insertKeyword(): Search keyword error";
        return next(err);
    }
    // 如果沒有 keyword_relation_id ，就創一個
    if ( !keyword_relation_id ) {
        fakeReq = {
            query: { relation:'' }
        };
        try {
            let insertKeywordRelationResult = await callAndCatchApiSuccess ( insertKeyword, fakeReq );
            keyword_relation_id = insertKeywordRelationResult.insertId;
        } catch (err) {
            err.desc = "middlewares-insertKeyword(): database insert error ( relation )";
            return next(err);
        }
    }

    if ( !keyword_relation_id ) {
        let err = new Error("keyword_relation_id cannot be null");
        err.desc = "middlewares-insertKeywrod(): keyword_relation_id cannot be null";
        return next(err);
    }

    // insert 進 keyword_data
    let sql = `
        INSERT INTO keyword_data ( keyword_text, keyword_relation_id)
        VALUE ( ?, ? )
    `;
    let params = [text, keyword_relation_id];
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