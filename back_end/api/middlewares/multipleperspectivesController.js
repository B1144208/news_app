const pool = require('../connect_db');
const { checkRequireField } = require('../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');

// search
async function searchMultipleperspectives(req, res, next) {
    let id = req.query?.id;

    // 檢查必要欄位 & 格式 - id
    try {
        [id] = await checkRequireField([
            { field: 'id', data: id, type: 'number' }
        ]);
    } catch (err) {
        err.desc = "middlewares-searchMultipleperspectives(): Invalid ID format";
        return next(err);
    }


    let sql = `SELECT * FROM multipleperspectives_data`;
    let params = [];
    if (id) {
        sql += ` WHERE multipleperspectives_id = ?`;
        params.push(id);
    }

    try {
        // 第一步：查詢主資料
        const [mainResult] = await pool.query(sql, params);

        // 如果主資料為空，直接回傳成功空陣列
        if (!mainResult || mainResult.length === 0) {
            return res.apiSuccess([], "Search Success");
        }

        // 第二步：針對每一筆主資料，同時查詢其相關的看法統整與留言
        const allResults = await Promise.all(mainResult.map(async (row) => {
            const dataId = row.multipleperspectives_id;
            const sqlViewpoints = `
                SELECT
                    integrate_title AS title,
                    integrate_content AS content,
                    CAST(integrate_percent AS DECIMAL(5,4)) AS percent
                FROM multipleperspectives_integrate
                WHERE multipleperspectives_id = ?
            `;
            const sqlDiscussions = `
                SELECT discuss AS content
                FROM multipleperspectives_discuss
                WHERE multipleperspectives_id = ?
            `;

            // 同時執行這兩個子查詢
            const [viewpoints, discussions] = await Promise.all([
                pool.query(sqlViewpoints, [dataId]),
                pool.query(sqlDiscussions, [dataId])
            ]);

            // 將所有資料合併到主物件
            return {
                ...row,
                viewpoints: viewpoints[0],
                discussions: discussions[0]
            };
        }));

        return res.apiSuccess(allResults, "Search Success");
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
        multipleperspectives_id
    ) VALUE (?)
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