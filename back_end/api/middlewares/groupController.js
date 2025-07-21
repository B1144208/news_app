const pool = require('../connect_db');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');

// search
async function searchGroup (req, res, next) {

    const name = req.query.name;

    let sql = `
        SELECT * 
        FROM group_data
        NATURAL JOIN group_detail
        WHERE 1
    `
    let params = []

    // general search
    if ( !name ) {
        try {
            let [result] = await pool.query(sql, params);
            return res.apiSuccess(result)
        } catch (err){
            err.desc = 'middlewares-searchGroup(): database search error (general search)'
            return next(err)
        }
    }

    // name search
    try {
        
        params = [`%${name}%`];

        // 先查 group_data
        sql = `
            SELECT * 
            FROM group_data
            WHERE group_name LIKE ?
        `
        let [data_result] = await pool.query(sql, params);
        if ( data_result.length > 0 ) {
            return res.apiSuccess({
                type: 'data',
                id: data_result[0].group_id
            }, 'Search Success');
        }

        // 再查 group_detail
        sql = `
            SELECT * 
            FROM group_detail
            WHERE group_detail_name LIKE ?
        `
        let [detail_result] = await pool.query(sql, params);
        if ( detail_result.length > 0 ) {
            return res.apiSuccess({
                type: 'detail',
                id: detail_result[0].group_detail_id
            }, 'Search Success');
        }
        
        // 都沒有
        return res.apiError(new Error('Not Found Group'), 404);

    } catch (err) {
        err.desc = 'middlewares-searchGroup(): database search error (name search)';
        return next(err);
    }
}

// insert
async function insertGroup(req, res, next) {

    // id: 
    // 1. group_detail_id   : 插入 group_detail
    // 2. null              : 插入 group_data
    // 3. 'other'           : 判斷 name 是否能 search 到，如果不行則插入'其他'分類的 group_detail 中
    let { id, name } = req.body;

    // 檢查必要欄位
    if ( !name || name.trim() === '' ) {
        let err = new Error('Internal Server Error')
        err.desc = 'middlewares-insertGroup(): Missing required fields - name'
        err.status = 400
        return next(err)
    }

    // 檢查 id 是否合法
    if ( id  && id !== 'other' && isNaN( Number( id ) ) ) {
        let err = new Error('middlewares-insertGroup(): Invalid Number - id');
        err.status = 400;
        console.warn('[Invalid Number]', err.message);

        id = null;
    }

    // 查找 group
    async function search ( name ) {
        try {
            fakeReq = {
                query: {
                    name: name
                }
            }
            const searchGroupResult = await callAndCatchApiSuccess ( searchGroup, fakeReq );
            return searchGroupResult;
            
        } catch (err) {
            console.warn('[Search Group Failed]', err.message);
        }
    }

    // 1. 查找是否已經有 group
    try {
        const searchGroupResult = await search ( name );
        if ( searchGroupResult?.type && searchGroupResult?.id ) {
            return res.apiSuccess ( searchGroupResult, 'Search Success' );
        }
    } catch (err) {}

    // 2. 查找'其他'位置
    if ( id === 'other' ) {
        try {
            const searchGroupResult = await search ( '其他' );
            id = searchGroupResult.id;
        } catch (err) {
            err.desc = 'middlewares-insertGroup(): database search error ( \'other\' )';
            return next(err);
        }
    }

    // 3. 插入資料庫
    let sql = ''
    let params = []
    try {
        // group_data 插入
        if ( !id ) {
            sql = `
                INSERT INTO group_data (
                    group_name
                ) VALUES (?)
            `;
            params = [ name ]
        } 
        // group_detail 插入
        else {
            sql = `
                INSERT INTO group_detail (
                    group_id,
                    group_detail_name
                ) VALUES (?, ?)
            `;
            params = [ id, name ]
        }
        
        let [result] = await pool.query(sql, params);

        return res.apiSuccess({
            type: sql.includes('group_data')? 'data': 'detail',
            id: result.insertId
        }, 'Insert Success');

    } catch (err) {
        err.desc = 'middlewares-insertGroup(): database insert error'
        return next(err);
    }
}

// update
async function updateGroup(req, res, next) {
    return;
}

// delete
async function deleteGroup(req, res, next) {
    const { type, id } = req.params;
    return;
}

module.exports = {
    searchGroup,
    insertGroup,
    updateGroup,
    deleteGroup
}