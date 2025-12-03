const pool = require('../connect_db');
const { checkRequireField } = require('../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');

// search
async function searchEventsorting (req, res, next) {
    let id = req.query?.id;

    // 檢查必要欄位 & 格式 - id
    try {
        // 允許 id 是可選的，以便進行一般搜索
        // 但如果 id 存在，則確保它是數字格式
        if (id !== undefined) {
             [ id ] = await checkRequireField ([
                { field: 'id' , data: id , type: 'number' }
            ]);
        }
    } catch (err) {
        err.desc = "middlewares-searchEventsorting(): Invalid required fields format";
        return next(err);
    }

    // 透過 LEFT JOIN 連接 eventsorting_data, eventsorting_horizontal, 和 eventsorting_vertical
    // 💥 新增 JOIN 到 relation_data 以獲取 relation_data.total_heat
    let sql =  `
        SELECT
            ed.*,
            GROUP_CONCAT(DISTINCT eh.horizontal_id) AS horizontal_events,
            GROUP_CONCAT(DISTINCT ev.news_id) AS vertical_news
        FROM eventsorting_data AS ed
        LEFT JOIN eventsorting_horizontal eh
            ON ed.eventsorting_id = eh.eventsorting_id
        LEFT JOIN eventsorting_vertical ev
            ON ed.eventsorting_id = ev.eventsorting_id
        WHERE 1
        
    `;
    let params = [];
    if ( id ) {
        sql += ` AND ed.eventsorting_id=?`;
        params.push( id );
    }



    // GROUP BY 是必要的，因為使用了 GROUP_CONCAT 聚合函數
    sql += ` GROUP BY ed.eventsorting_id`;

    // 💥 添加 ORDER BY 子句，根據計算出的 sorting_score 降序排列
    sql += ` ORDER BY ed.total_heat DESC
             LIMIT 1000;`;


    try {
        let [result] = await pool.query( sql, params);

        // 處理結果：將 GROUP_CONCAT 產生的逗號分隔字串轉換為數字陣列
        const processedResult = result.map(row => ({
            ...row,
            // 將 'horizontal_events' 字串轉換為數字陣列，若為空則為空陣列
            horizontal_events: row.horizontal_events ? row.horizontal_events.split(',').map(Number) : [],
            // 將 'vertical_news' 字串轉換為數字陣列，若為空則為空陣列
            vertical_news: row.vertical_news ? row.vertical_news.split(',').map(Number) : [],
        }));

        return res.apiSuccess( processedResult, "Search Success");
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