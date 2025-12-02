const pool = require('../connect_db');
const { checkRequireField } = require('../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');
const https = require('https');
const http = require('http');

// search
async function searchImage (req, res, next) {

    let { src, alt } = req.body ?? {};

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

// ========== 新增：圖片代理端點 ==========
async function proxyImage(req, res, next) {
    const imageUrl = req.query.url;

    if (!imageUrl) {
        return res.status(400).json({
            success: false,
            message: 'Missing image URL parameter'
        });
    }

    try {
        // 驗證 URL
        const url = new URL(imageUrl);
        const protocol = url.protocol === 'https:' ? https : http;

        // 發送請求獲取圖片
        protocol.get(imageUrl, (imageResponse) => {
            // 檢查響應狀態
            if (imageResponse.statusCode !== 200) {
                return res.status(imageResponse.statusCode).json({
                    success: false,
                    message: 'Failed to fetch image'
                });
            }

            // 設置 CORS headers
            res.setHeader('Access-Control-Allow-Origin', '*');
            res.setHeader('Access-Control-Allow-Methods', 'GET');
            res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

            // 轉發 content-type
            const contentType = imageResponse.headers['content-type'];
            if (contentType) {
                res.setHeader('Content-Type', contentType);
            }

            // 設置緩存 header
            res.setHeader('Cache-Control', 'public, max-age=86400'); // 緩存 24 小時

            // 將圖片流轉發給客戶端
            imageResponse.pipe(res);

        }).on('error', (error) => {
            console.error('圖片代理錯誤:', error);
            res.status(500).json({
                success: false,
                message: 'Error fetching image',
                error: error.message
            });
        });

    } catch (error) {
        console.error('圖片代理錯誤:', error);
        res.status(400).json({
            success: false,
            message: 'Invalid image URL',
            error: error.message
        });
    }
}

// insert
async function insertImage (req, res, next) {
    let { img } = req.body ?? {};

    // 檢查必要欄位 & 格式 -
    try {
        [ img ] = await checkRequireField ([
            { field: 'img'   , data: img  , type: 'image'    , other: ['non_null'] }
        ]);
    } catch (err) {
        err.desc = "middlewares-insertImage(): Missing or Invalid required fields";
        return next(err);
    }
    const src = img.src, alt = img.alt;

    // 先 search img
    let fakeReq = {
        body: { src: src, alt: alt }
    };

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
    let id = req.params?.id;
    const has = req.query?.has !== undefined;

    // 檢查必要欄位 & 格式 - id
    try {
        [ id ] = await checkRequireField ([
            { field: 'id' , data: id , type: 'number' , other: ['non_null'] }
        ]);
    } catch (err) {
        err.desc = "middlewares-deleteImage(): Missing or Invalid required fields";
        return next(err);
    }

    // 檢查是否有 news 使用
    if ( has ) {
        let sql = `
            SELECT image_id
            FROM image_data
            NATURAL JOIN (
                SELECT cover_image AS image_id FROM news_data
                UNION
                SELECT body_image AS image_id FROM news_body
            ) AS used_image
            WHERE image_id=?
        `;
        let params = [ id ];

        try {
            let [result] = await pool.query(sql, params);
            if( result.length !== 0 ) {
                return res.apiSuccess({}, "Search Success");
            }
        } catch (err) {
            err.desc = 'middlewares-deleteImage(): search Image is already has error';
            return next(err);
        }
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
    deleteImage,
    proxyImage  // 新增：導出代理函數
};