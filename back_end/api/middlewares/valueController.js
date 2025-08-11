const pool = require('../connect_db');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');

// search
async function searchValue (req, res, next) {
    
    const type = req.query?.type;

    // 檢查必要欄位 & 格式 - type
    try {
        [ type ] = await checkRequireField ([
            { field: 'type'   , data: type  , type: 'string' }
        ]);
    } catch (err) {
        err.desc = "middlewares-searchValue(): Missing or Invalid required fields";
        return next(err);
    }

    
    let sql = `
        SELECT * FROM value_adjust
        WHERE 1
    `;
    let params = [];

    if ( type ) {
        sql += ` AND adjust_type=?`;
        params.push(type);
    }

    try {
        let [result] = await pool.query(sql, params);
        return res.apiSuccess(result, "Search Success");
    } catch (err) {
        err.desc = "middlewares - valueController(): database search error";
        return next(err);
    }
}

// insert
async function insertValue (req, res, next) {
    const { type, value } = req.body ?? {};

    // 檢查必要欄位 & 格式 - type, value
    try {
        [ type, value ] = await checkRequireField ([
            { field: 'type'     , data: type    , type: 'string'    , need: ['non_null'] },
            { field: 'value'    , data: value   , type: 'number'    , need: ['non_null'] }
        ]);
    } catch (err) {
        err.desc = "middlewares-insertValue(): Missing or Invalid required fields";
        return next(err);
    }


}

// update
async function updateValue(req, res, next) {
    return;
}

// delete
async function deleteValue(req, res, next) {

    const type = req.params?.type;

    // 檢查必要欄位 & 格式 - type
    try {
        [ type ] = await checkRequireField ([
            { field: 'type' , data: type    , type: 'string'    , need: ['non_null'] }
        ]);
    } catch (err) {
        err.desc = "middlewares-searchValue(): Missing or Invalid required fields";
        return next(err);
    }

    let sql =  `
        DELETE FROM value_adjust
        WHERE type=?
    `
    let params = [type];
    try {
        let [result] = await pool.query(sql, params);

        // 如果沒有刪除任何資料
        if (result.affectedRows === 0) {
            let err = new Error('Adjust_Type not found')
            err.desc = 'middlewares-deleteValue(): Adjust_Type not found';
            err.status = 404;
            return next(err);
        }

        return res.apiSuccess(result, "Search Success");
    } catch (err) {
        err.desc = "middlewares - valueController(): database search error";
        return next(err);
    }
}

module.exports = {
    searchValue,
    insertValue,
    updateValue,
    deleteValue
}