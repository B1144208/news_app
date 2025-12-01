const pool = require('../connect_db');
const { checkRequireField } = require('../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');
const { getEmbedding, findKeywordRelationId } = require('../utils/embeddingHelper');

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
async function insertKeyword(req, res, next) {
        let text = req.body?.text || req.query?.text;

        const relation = req.query?.relation !== undefined;

        // 檢查必要欄位 & 格式 - text
        try {

            // ⭐ 修正 #2：確保 relation=true (內部呼叫) 時，不檢查 non_null ⭐
            let checkList;

            if (relation) {
                // 情境 1: 內部呼叫創建 keyword_relation_id (text此時為 null)
                checkList = [
                    { field: 'text' , data: text , type: 'string' }
                ];
            } else {
                // 情境 2: 正常的外部呼叫插入關鍵字
                checkList = [
                    { field: 'text' , data: text , type: 'string' , other: ['non_null'] }
                ];
            }

            [ text ] = await checkRequireField (checkList);

        } catch (err) {
            err.desc = "middlewares-insertKeyword(): Missing or Invalid required fields";
            return next(err);
        }

    // 如果 req.query 帶有 relation 參數，則執行「創建 keyword_relation_id」邏輯
    if ( relation ) {
        // 只有當 text 為 null 時才執行創建 (這是 insertKeyword 內部呼叫時的行為)
        if ( !text ) {
            let sql = `
                INSERT INTO keyword_relation ()
                VALUE ()
            `;
            try {
                let [result] = await pool.query(sql);
                return res.apiSuccess({ insertId: result.insertId }, "Insert Success");
            } catch (err) {
                err.desc = "middlewares-insertKeywrod(): database insert error ( relation )";
                return next(err);
            }
        }
    }

    // ----------------------------------------------------------------------------------------
    // 【Keyword 插入流程開始】(只在非 relation 呼叫時執行)
    // ----------------------------------------------------------------------------------------

    // 1. 檢查 Keyword 是否已存在 (原有的 search 邏輯)
    let fakeReq = {
        query: { text: text }
    };
    try {
        let searchKeywordResult = await callAndCatchApiSuccess ( searchKeyword, fakeReq );
        if ( Array.isArray(searchKeywordResult) && searchKeywordResult.length > 0 ) {
            // Keyword 存在，直接返回 ID
            return res.apiSuccess({ insertId: searchKeywordResult[0].keyword_id }, "Search Success" );
        }
    } catch (err) {
        err.desc = "middlewares-insertKeyword(): Search keyword error";
        return next(err);
    }


    // 2. 獲取 keyword_embedding
    let newKeywordEmbedding;
    try {
        newKeywordEmbedding = await getEmbedding(text);
    } catch (err) {
        err.desc = "middlewares-insertKeyword(): ollama use error ( embedding )";
        return next(err);
    }
    const embeddingJson = JSON.stringify(newKeywordEmbedding);


    // 3. 判斷 keyword_relation_id (使用 Embedding 優先判斷)
    let keyword_relation_id = null;
    try {
        const sql = `
            SELECT
                keyword_relation_id,
                keyword_embedding
            FROM keyword_data
            WHERE keyword_embedding IS NOT NULL
            AND keyword_relation_id IS NOT NULL;
        `;
        const [rows] = await pool.query(sql);

        const existingKeywords = rows.map(row => {
            let embedding;
            try {
                embedding = JSON.parse(row.keyword_embedding);
            } catch (e) {
                console.error(`Error parsing embedding for keyword_relation_id ${row.keyword_relation_id}:`, e);
                embedding = null;
            }

            return {
                keyword_relation_id: row.keyword_relation_id,
                keyword_embedding: embedding
            };
        }).filter(item => item.keyword_embedding !== null);

        const matchedRelationId = findKeywordRelationId(newKeywordEmbedding, existingKeywords, 0.75);

        if (matchedRelationId !== null) {
            keyword_relation_id = matchedRelationId;
            //console.log(`[Keyword Match] 找到相似度 > 0.75 的 keyword_relation_id: ${keyword_relation_id}`);
        } else {
            //console.log(`[Keyword Match] 未找到匹配，將執行舊有邏輯（Search/Insert Relation）。`);
        }

    } catch (err) {
        console.error('middlewares-insertKeyword(): database/embedding logic error', err);
    }

    // 4. Fallback 邏輯：如果 Embedding 判斷未找到匹配 (keyword_relation_id 仍為 null)
    if ( keyword_relation_id === null ) {

        // a. 先 search keyword_relation_id (使用 keyword_text LIKE)
        fakeReq = {
            query: { text: text , relation:'' }
        };
        try {
            let searchKeywordRelationResult = await callAndCatchApiSuccess ( searchKeyword, fakeReq );
            if ( searchKeywordRelationResult.success ) {
                keyword_relation_id = searchKeywordRelationResult.searchId;
            }
        } catch (err) {
            err.desc = "middlewares-insertKeyword(): Search keyword relation error";
            return next(err);
        }

        // b. 如果沒有 keyword_relation_id ，就創一個
        if ( !keyword_relation_id ) {
            fakeReq = {
                // 這裡故意不傳 body，讓它進入上面的 if ( relation ) 區塊來創建 ID
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
    }

    if ( !keyword_relation_id ) {
        let err = new Error("keyword_relation_id cannot be null");
        err.desc = "middlewares-insertKeywrod(): keyword_relation_id cannot be null after all checks";
        return next(err);
    }

    // 5. 插入 keyword_data
    let sql = `
        INSERT INTO keyword_data ( keyword_text, keyword_embedding, keyword_relation_id)
        VALUE ( ?, ?, ? )
    `;
    let params = [text, embeddingJson, keyword_relation_id];
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