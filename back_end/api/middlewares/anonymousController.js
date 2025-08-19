const pool = require('../connect_db');
const { checkRequireField } = require('../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');

// search
async function searchAnonymous (req, res, next) {
    let { name, id } = req.body ?? {};

    // 檢查必要欄位 & 格式 - name
    try {
        [ name, id ] = await checkRequireField ([
            { field: 'name' , data: name    , type: 'string' },
            { field: 'id'   , data: id      , type: 'number' }
        ]);
    } catch (err) {
        err.desc = "middlewares-searchAnonymous(): Missing or Invalid required fields";
        return next(err);
    }

    // general search
    let sql = `
        SELECT * 
        FROM anonymous_name
        WHERE 1
    `;
    let params = [];

    // name, id search
    if ( id ) {
        sql += ` AND anonymous_id=?`;
        params.push( id );
    } else if (name) {
        sql += ` AND anonymous_name=?`;
        params.push( name );
    }
    try {
        let [result] = await pool.query( sql, params );
        if ( result.length === 0) 
            return res.apiSuccess({ success: false }, "Search Not Found");
        
        if ( name )
            return res.apiSuccess({ success: true, searchId: result[0].anonymous_id }, "Search Success");

        return res.apiSuccess(result, "Search Success");
    } catch (err) {
        err.desc = "middlewares-searchAnonymous(): database search error";
        return next(err);
    }
}

// insert
async function insertAnonymous (req, res, next) {
    let name = req.query?.name;

    // 檢查必要欄位 & 格式 - name
    try {
        [ name ] = await checkRequireField ([
            { field: 'name' , data: name , type: 'string' , other: ['non_null'] }
        ]);
    } catch (err) {
        err.desc = "middlewares-insertAnonymous(): Missing or Invalid required fields";
        return next(err);
    }

    // 先 search
    let fakeReq = {
        body: { name: name }
    }
    try {
        let searchAnonymousResult = await callAndCatchApiSuccess ( searchAnonymous, fakeReq );
        if ( searchAnonymousResult.success )
            return res.apiSuccess({ insertId: searchAnonymousResult.searchId }, "Search Success");
    } catch (err) {
        err.desc = "middlewares-insertAnonymous(): Search Anonymous Error";
        return next(err);
    }

    // 再 insert
    let sql = `
        INSERT INTO anonymous_name ( anonymous_name )
        VALUES (?)
    `;
    let params = [ name ];
    try {
        let [result] = await pool.query(sql, params);
        return res.apiSuccess( { insertId: result.insertId }, "Insert Success");
    } catch (err) {
        err.desc = "middlewares-insertAnonymous(): database insert error";
        return next(err);
    }
}

// update
async function updateAnonymous(req, res, next) {
    return;
}

// delete
async function deleteAnonymous(req, res, next) {
    return;
}

module.exports = {
    searchAnonymous,
    insertAnonymous,
    updateAnonymous,
    deleteAnonymous
}