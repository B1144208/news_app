const pool = require('../connect_db');
const { checkRequireField } = require('../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');

// search
async function searchMultipleperspectives (req, res, next) {
    let id = req.query?.id;
    
    // 檢查必要欄位 & 格式 - id
    try {
        [ id ] = await checkRequireField ([
            { field: 'id' , data: id , type: 'number' }
        ]);
    } catch (err) {
        err.desc = "middlewares-searchMultipleperspectives(): Missing or Invalid required fields";
        return next(err);
    }

    let sql =  `
        SELECT * 
        FROM multipleperspectives_data
        WHERE 1
    `;
    let params = [];

    if ( id ) {
        sql += ` AND multipleperspectives_id=?`;
        params.push( id );
    }

    try {
        let [result] = await pool.query( sql, params);
        return res.apiSuccess( result, "Search Success");
    } catch (err) {
        err.desc = "middlewares-searchMultipleperspectives(): database search error";
        return next(err);
    }
}

// insert
async function insertMultipleperspectives (req, res, next) {
    let { id, title } = req.body ?? {};

    // 檢查必要欄位 & 格式 - id, title
    try {
        [ id ] = await checkRequireField ([
            { field: 'id'       , data: id      , type: 'number'    , other: ['non_null'] },
            { field: 'title'    , data: title   , type: 'string'                          }
        ]);
    } catch (err) {
        err.desc = "middlewares-insertEventsorting(): Missing or Invalid required fields";
        return next(err);
    }

    let sql = `
    INSERT INTO multipleperspectives_data (
        multipleperspectives_id,
        multipleperspectives_title
    ) VALUE (?, ?)
    `;
    let params = [ id, title ];

    try {
        let [result] = await pool.query( sql, params);
        return res.apiSuccess( {insertId: result.insertId }, "Insert Success");
    } catch (err) {
        err.desc = "middlewares-multipleperspectivesController(): database insert error";
        return next(err);
    }
}

// update
async function updateMultipleperspectives(req, res, next) {
    return;
}

// delete
async function deleteMultipleperspectives(req, res, next) {
    let id = req.params?.id;

    // 檢查必要欄位 & 格式 - id
    try {
        [ id ] = await checkRequireField ([
            { field: 'id' , data: id , type: 'number' , other: ['non_null']}
        ]);
    } catch (err) {
        err.desc = "middlewares-deleteMultipleperspectives(): Missing or Invalid required fields";
        return next(err);
    }

    let sql =  `
        DELETE FROM multipleperspectives_data
        WHERE multipleperspectives_id=?
    `
    let params = [ id ];
    try {
        let [result] = await pool.query(sql, params);

        // 如果沒有刪除任何資料
        if (result.affectedRows === 0) {
            let err = new Error('Multipleperspectives not found')
            err.desc = 'middlewares-deleteMultipleperspectives(): Multipleperspectives not found';
            err.status = 404;
            return next(err);
        }

        return res.apiSuccess({}, "Delete Success");
    } catch (err) {
        err.desc = "middlewares-deleteMultipleperspectives(): database delete error";
        return next(err);
    }
}

module.exports = {
    searchMultipleperspectives,
    insertMultipleperspectives,
    updateMultipleperspectives,
    deleteMultipleperspectives
}