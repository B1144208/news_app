const fs = require('fs').promises;
const pool = require('../connect_db');
const { checkRequireField } = require('../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper')
const { insertImage, deleteImage } = require('./imageController')

// search
async function searchChannel(req, res, next) {
    let name = req.query?.name;

    let sql = `
        SELECT * 
        FROM channel_data 
        WHERE 1
    `;
    let params = [];

    // 檢查必要欄位 & 格式 - name
    if (name) {
        try {
            [ name ] = await checkRequireField ([
                { field: 'name' , data: name , type: 'string' }
            ]);
        } catch (err) {
            err.desc = "middlewares-searchChannel(): Missing or Invalid required fields";
            return next(err);
        }
    }

    // general search
    if (!name) {
        try {
            let [result] = await pool.query(sql, params);
            return res.apiSuccess(result, 'Search Success');
        } catch (err) {
            err.desc = 'middlewares-searchChannel(): database search error';
            return next(err);
        }
    }

    // name search
    try {
        
        sql = `
            SELECT * 
            FROM channel_data
            WHERE channel_name LIKE ?
        `;
        params = [`${name}%`];
        let [result] = await pool.query(sql, params);

        if (result.length > 0) {
            return res.apiSuccess({
                searchId: result[0].channel_id
            }, 'Search Success');
        }

        // No results found
        const err = new Error('Not Found Channel');
        err.status = 404;
        err.desc = 'middlewares-searchChannel(): database search error (name search - not found channel)';
        throw err;
        
        //return res.apiError(new Error('Not Found Channel'), 404);

    } catch (err) {
        err.desc = 'middlewares-searchChannel(): database search error (name search)';
        return next(err);
    }
}

// insert
async function insertChannel(req, res, next) {
    let { url=null, img=null, name, type=null, introduce=null } = req.body ?? {};

    // 檢查必要欄位 & 格式 - name
    try {
        [ url, img, name, type, introduce ] = await checkRequireField ([
            { field: 'url'          , data: url         , type: 'string' },
            { field: 'img'          , data: img         , type: 'string' },
            { field: 'name'         , data: name        , type: 'string'    , other: ['non_null'] },
            { field: 'type'         , data: type        , type: 'string' },
            { field: 'introduce'    , data: introduce   , type: 'string' }
        ]);
    } catch (err) {
        err.desc = "middlewares-insertChannel(): Missing or Invalid required fields";
        return next(err);
    }

    // 先 search channel
    try {
        let fakeReq = {
            query: { name: name }
        };
        let result = await callAndCatchApiSuccess( searchChannel, fakeReq );
        return res.apiSuccess( { insertId: result.searchId }, "Search Success");
    } catch (err) {}

    // Insert image if provided
    let img_id = null
    if (img) {
        try {
            let fakeReq = { 
                body: { img: { src: img, alt: null } } 
            };
            const result = await callAndCatchApiSuccess( insertImage, fakeReq );
            img_id = result.insertId;
        } catch (err) {
            console.warn('[Insert Image Failed]', err.message);
        }
    }

    const sql = `
        INSERT INTO channel_data (
            origin_url, 
            image_id, 
            channel_name, 
            channel_type, 
            channel_introduction
        ) VALUES (?, ?, ?, ?, ?)
    `;
    const params = [url, img_id, name, type, introduce];

    try {
        const [result] = await pool.query(sql, params);
        return res.apiSuccess({ insertId: result.insertId }, 'Insert Success');
    } catch (err) {
        err.desc = 'middlewares-insertChannel(): database insert error';

        // Try to clean up inserted image if insertion failed
        if ( img_id ) {
            try {
                let fakeReq = { 
                    params: { id: img_id } 
                };
                await callAndCatchApiSuccess( deleteImage, fakeReq );
            } catch (deleteErr) {
                deleteErr.desc = err.desc + ' & image delete error';
                return next(deleteErr);
            }
        }

        return next(err);
    }
}

// update
async function updateChannel(req, res, next) {
    return;
}

// delete
async function deleteChannel(req, res, next) {
    let id = req.params?.id;
    const has = req.query?.has !== undefined;

    // 檢查必要欄位 & 格式 - id
    try {
        [ id ] = await checkRequireField ([
            { field: 'id' , data: id , type: 'number' , other: ['non_null'] }
        ]);
    } catch (err) {
        err.desc = "middlewares-deleteChannel(): Missing or Invalid required fields";
        return next(err);
    }

    // 檢查是否有 news 包含其中
    if ( has ) {
        let sql = `
            SELECT channel_id
            FROM channel_data
            NATURAL JOIN (
                SELECT channel_id FROM news_data
            ) AS used_channel
            WHERE channel_id=?;
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
        DELETE FROM channel_data 
        WHERE channel_id = ?
    `;
    let params = [ id ]
    try {
        let [result] = await pool.query(sql, params);

        // 如果沒有刪除任何資料
        if (result.affectedRows === 0) {
            let err = new Error('Channel not found')
            err.desc = 'middlewares-deleteChannel(): Channel not found';
            err.status = 404;
            return next(err);
        }

        res.apiSuccess( null, 'Delete Success' )
    } catch (err) {
        err.desc = 'middlewares-deleteChannel(): database delete error'
        return next(err)
    }
    return;
}

module.exports = {
    searchChannel,
    insertChannel,
    updateChannel,
    deleteChannel
};