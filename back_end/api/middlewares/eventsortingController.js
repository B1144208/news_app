const pool = require('../connect_db');
const { checkRequireField } = require('../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');

// search
async function searchEventsorting (req, res, next) {
    let id = req.query?.id;
    
    // 檢查必要欄位 & 格式 - id
    try {
        [ id ] = await checkRequireField ([
            { field: 'id' , data: id , type: 'number' }
        ]);
    } catch (err) {
        err.desc = "middlewares-searchEventsorting(): Missing or Invalid required fields";
        return next(err);
    }

    let sql =  `
        SELECT * 
        FROM eventsorting_data
        WHERE 1
    `;
    let params = [];
    if ( id ) {
        sql += ` AND eventsorting_id=?`;
        params.push( id );
    }
    try {
        let [result] = await pool.query( sql, params);
        return res.apiSuccess( result, "Search Success");
    } catch (err) {
        err.desc = "middlewares-searchEventsorting(): database search error";
        return next(err);
    }
}

// insert
async function insertEventsorting (req, res, next) {
    let { id, img_id, title, summary } = req.body ?? {};

    // 檢查必要欄位 & 格式 - id, img_id, title, summary
    try {
        [ id ] = await checkRequireField ([
            { field: 'id'       , data: id      , type: 'number'    , other: ['non_null'] },
            { field: 'img_id'   , data: img_id  , type: 'number'                          },
            { field: 'title'    , data: title   , type: 'string'                          },
            { field: 'summary'  , data: summary , type: 'string'                          }
        ]);
    } catch (err) {
        err.desc = "middlewares-insertEventsorting(): Missing or Invalid required fields";
        return next(err);
    }

    let sql = `
        INSERT INTO eventsorting_data (
            eventsorting_id,
            eventsorting_image,
            eventsorting_title,
            eventsorting_summary
        ) VALUE (?, ?, ?, ?)
    `;
    let params = [ id, img_id, title, summary ];

    try {
        let [result] = await pool.query( sql, params);
        return res.apiSuccess( {insertId: result.insertId }, "Insert Success");
    } catch (err) {
        err.desc = "middlewares-eventsortingController(): database insert error";
        return next(err);
    }
}

// update
async function updateEventsorting(req, res, next) {
    return;
}

// delete
async function deleteEventsorting(req, res, next) {
    let id = req.params?.id;

    // 檢查必要欄位 & 格式 - id
    try {
        [ id ] = await checkRequireField ([
            { field: 'id' , data: id , type: 'number' , other: ['non_null']}
        ]);
    } catch (err) {
        err.desc = "middlewares-searchEventsorting(): Missing or Invalid required fields";
        return next(err);
    }

    let sql =  `
        DELETE FROM eventsorting_data
        WHERE eventsorting_id=?
    `
    let params = [ id ];
    try {
        let [result] = await pool.query(sql, params);

        // 如果沒有刪除任何資料
        if (result.affectedRows === 0) {
            let err = new Error('Eventsorting not found')
            err.desc = 'middlewares-deleteEventsorting(): Eventsorting not found';
            err.status = 404;
            return next(err);
        }

        return res.apiSuccess({}, "Delete Success");
    } catch (err) {
        err.desc = "middlewares-deleteEventsorting(): database delete error";
        return next(err);
    }
}

module.exports = {
    searchEventsorting,
    insertEventsorting,
    updateEventsorting,
    deleteEventsorting
}