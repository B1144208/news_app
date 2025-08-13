const pool = require('../connect_db');
const { checkRequireField } = require('../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');
const { insertKeyword } = require('./keywordController');

// search
async function searchRelation (req, res, next) {
    
    let id = req.query?.id;
    const relation_keyword = req.query?.relation_keyword !== undefined;
    let { keyword } = req.body ?? {};
    
    // 1. 查詢 relation
    let sql = `
        SELECT * 
        FROM relation_data
        WHERE 1
    `;
    let params = [];

    // 2. 查詢 relation_keyword
    if ( relation_keyword ) {
        sql = `
            SELECT relation_id, relation_summary, keyword_id, keyword_text 
            FROM relation_data
            NATURAL JOIN relation_keyword
            NATURAL JOIN keyword_data
            WHERE 1
        `;
    }

    // 3. 查詢限定 relation_id
    if ( id ) {
        sql += ` AND relation_id=?`;
        params.push(id);
    }

    // 4. 精準查詢
    if ( keyword ) {

        // a. 用 keyword 篩選出 relationSet
        const relationSet = new Set();
        const searchTasks = keyword.map( async (item) => {
            sql = `
                SELECT relation_id
                FROM relation_data
                NATURAL JOIN relation_keyword
                NATURAL JOIN keyword_data
                WHERE keyword_text = ?
            `;
            params = [item];
            try {
                let [result] = await pool.query( sql, params );
                if ( result.length > 0 ) {
                    result.forEach(row => {
                        // 確保 relation_id 唯一
                        if ( ![...relationSet].some( existing => existing.id === row.relation_id ) ) {
                            // 只有 relation_id 不重複時才插入 Set
                            relationSet.add({ id: row.relation_id, summary: row.relation_summary });
                        }
                    });
                }
            } catch (err) {
                err.desc = "middlewares - searchRelation(): database search error - exact search ( keyword )"
                throw err;
            }
        });
        try {
            await Promise.all(searchTasks);
            return res.apiSuccess( [...relationSet], "Search Success");
        } catch(err) {
            return next(err);
        }

        // b. 用 ai 比對 relation_summary ， {data: relationSet}
        // ----------------------------------------------------------------------------------------------------------
        
    }
    
    // 1. 2. 3. 查詢
    try {
        let [result] = await pool.query(sql, params);
        return res.apiSuccess(result, "Search Success");
    } catch (err) {
        err.desc = "middlewares - searchRelation(): database search error - general search";
        return next(err);
    }
}

// insert
async function insertRelation (req, res, next) {
    
    let { keyword } = req.body ?? {};

    // 處理 keyword
    /*keyword = (Array.isArray(keyword))
        ? keyword.filter(item => item && typeof item === 'string' && item.trim() !== '').map(item => item.trim())
        : (keyword && typeof keyword === 'string' && keyword.trim() !== '') 
            ? [keyword.trim()]
            : [];

   // 確保 keyword 是有效的陣列，即使它是 null 或 undefined
    if (!Array.isArray(keyword)) {
        keyword = [];  // 如果 keyword 不是陣列，將其設為空陣列
    } else {
        // 過濾掉空值或無效的項目，並保證每個項目是有效字串
        keyword = keyword.filter(item => item && typeof item === 'string' && item.trim() !== '')
                        .map(item => item.trim());
    }*/

    try {
        [ keyword ] = await checkRequireField ([
            { field: 'keyword' , data: keyword , type: 'array' , other: ['string_into_array']  , array_filter: 'string' }
        ]);
    } catch (err) {
        err.desc = "middlewares-insertRelation(): Missing or Invalid required fields";
        return next(err);
    }

    // 獲取 relation_id
    let sql = `
        INSERT INTO relation_data( updated_at )
        VALUES (?)
    `;
    let params = [ new Date()];
    let [result] = await pool.query(sql, params);
    const relation_id = result.insertId;

    if ( keyword == null ) {
        return res.apiSuccess( { insertId: relation_id }, "Insert Seccess" );
    }

    // 插入 relation_keyword
    try {
        const insertionTasks = keyword.map ( async (item) => {
        
            if ( !item || typeof item !== 'string') return;

            // 獲取 keyword_id
            let keyword_id;
            let fakeReq = {
                query: { text: item }
            };
            try {
                let insertKeywordResult = await callAndCatchApiSuccess( insertKeyword, fakeReq );
                keyword_id = insertKeywordResult.insertId;
            } catch(err) {
                err.desc = "middlewares - insertRelation(): database insert error - ( keyword - keyword )";
                throw err;
            }

            // 插入 realtion_keyword
            let sql  = `
                INSERT INTO relation_keyword(relation_id, keyword_id) 
                VALUES (?, ?)
            `;
            let params = [relation_id, keyword_id];
            try {
                let [relationKeywordResult] = await pool.query(sql, params);
            } catch (err) {
                err.desc = "middlewares - insertRelation(): database insert error - ( keyword - relation_keyword )";
                throw err;
            }
        });

        
        await Promise.all(insertionTasks);
        return res.apiSuccess({ insertId: relation_id }, "Insert Success");
        
    } catch (err) {
        return next(err);
    }

}

// update
async function updateRelation(req, res, next) {
    return;
}

// delete
async function deleteRelation(req, res, next) {
    let id = req.params?.id;
    const has = req.query?.has !== undefined;

    // 檢查必要欄位 & 格式 - id
    try {
        [ id ] = await checkRequireField ([
            { field: 'id' , data: id , type: 'number' , other: ['non_null'] }
        ]);
    } catch (err) {
        err.desc = "middlewares-deleteRelation(): Missing or Invalid required fields";
        return next(err);
    }

    // 檢查是否有 news 包含其中
    if ( has ) {
        let sql = `
            SELECT relation_id
            FROM relation_data
            NATURAL JOIN (
                SELECT relation_id FROM news_data
            ) AS used_relation
            WHERE relation_id=?;
        `
        let params = [id]
        try {
            let [result] = await pool.query(sql, params);
            if ( result.length !== 0 ) {
                return res.apiSuccess({}, "Search Success");
            }
        } catch (err) {
            err.desc = 'middlewares-deleteChannel(): search Channel is already has error';
            return next(err);
        }
    }

    let sql = `
        DELETE FROM relation_data
        WHERE relation_id=?
    `;
    let params = [id];
    try {
        let [result] = await pool.query(sql, params);

        // 如果沒有刪除任何資料
        if (result.affectedRows === 0) {
            let err = new Error('Relation not found')
            err.desc = 'middlewares-deleteRelation(): Relation not found';
            err.status = 404;
            return next(err);
        }

        return res.apiSuccess({}, "Delete Success");
    } catch (err) {
        err.desc = "middlewares-deleteRelation(): database delete error";
        return next(err);
    }
}

module.exports = {
    searchRelation,
    insertRelation,
    updateRelation,
    deleteRelation
}