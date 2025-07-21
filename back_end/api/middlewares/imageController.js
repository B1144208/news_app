const pool = require('../connect_db');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');

// search
async function searchImage (req, res, next) {

    let { src, alt } = req.body;

    let sql = `
        SELECT * 
        FROM image_data 
        WHERE 1
    `
    let params = []
    if ( src ) {
        sql += ' AND ( image_origin_url = ? AND image_text = ? )';
        params = [src, alt || null]
    }
    
    try {
        let [result] = await pool.query(sql, params);

        // 找不到資料
        if (result.length === 0) {
            let err = new Error('Image not found');
            err.desc = 'middlewares-searchImage() : image not found';
            err.status = 404;
            return next(err);
        }

        // 找到資料
        res.apiSuccess(result, 'Search Success')

    } catch (err){
        err.desc = 'middlewares-searchImage() : database search error'
        return next(err)
    }
}

// insert
async function insertImage (req, res, next) {
    let { src, alt } = req.body;

    // 檢查必要欄位
    if (!src) {
        let err = new Error('Internal Server Error')
        err.desc = 'middlewares-insertImage() : Missing required fields - src'
        err.status = 400
        return next(err)
    }

    // res.body 處理
    alt = ( !alt || alt.trim() === '' )? null: alt;

    // 先 search img
    let fakeReq = {
        body: {
            src: src,
            alt: alt
        }
    }
    
    try {
        let result = await callAndCatchApiSuccess ( searchImage, fakeReq );
        if ( Array.isArray ( result ) && result.length > 0 ) {
            return res.apiSuccess({ insertId: result[0].image_id }, 'Search Success')
        }
    } catch (err) {
        if ( err.status !== 404 ) {
            err.desc = 'middlewares-insertImage() : database search error';
            return next(err);
        }
    }

    // search not found, insert into database
    let sql = `
        INSERT INTO image_data (
            image_origin_url,
            image_text
        ) VALUES (?, ?)
    `;
    let params = [ src, alt || null ]
    try {
        let [result] = await pool.query(sql, params);
        return res.apiSuccess({ insertId: result.insertId }, 'Insert Success')
    } catch (err) {
        err.desc = 'middlewares-insertImage() : database insert error'
        return next(err)
    }
}

// update
async function updateImage(req, res, next) {
    /*
    @ update 時，
    @ 如果有其他重複的，則另開一個新的img insert進去，news的img也要換id
    @ 沒有重複的直接更改就好
    */
    return;
}

// delete
async function deleteImage(req, res, next) {
    const id = req.params.id;

    // 檢查 id 是否有效
    if (!id || isNaN(id)) {
        let err = new Error('Invalid Number Error');
        err.desc = 'middlewares-deleteImage(): Missing or Invalid required fields - image_id';
        err.status = 400;
        return next(err);
    }

    let sql = `
        DELETE FROM image_data 
        WHERE image_id = ?
    `;
    let params = [ id ]
    try {
        let [result] = await pool.query(sql, params);

        // 如果沒有刪除任何資料
        if (result.affectedRows === 0) {
            let err = new Error('Image not found')
            err.desc = 'middlewares-deleteImage(): Image not found';
            err.status = 404;
            return next(err);
        }

        res.apiSuccess( null, 'Delete Success' )
    } catch (err) {
        err.desc = 'middlewares-deleteImage(): database delete error'
        return next(err)
    }
}

module.exports = {
    searchImage,
    insertImage,
    updateImage,
    deleteImage
};