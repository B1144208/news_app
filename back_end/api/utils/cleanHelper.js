const express = require('express');
const router = express.Router();
const pool = require('../connect_db')

// 清理 database
router.get('/', async (req, res, next) => {

    const news      = 'news'        in req.query;
    const channel   = 'channel'     in req.query;
    const image     = 'image'       in req.query;
    const keyword   = 'keyword'     in req.query;
    const relation  = 'relation'    in req.query;
    const error     = 'error'       in req.query;

    let sql = ''

    if ( news ) {
        sql += 'DELETE FROM news_data;'
    }if ( channel ) {
        sql += 'DELETE FROM channel_data;'
    }if ( image ) {
        sql += 'DELETE FROM image_data;'
    }if ( keyword ) {
        sql += 'DELETE FROM keyword_data;'
    }if ( relation ) {
        sql += 'DELETE FROM relation_data;'
    }if ( error ) {
        sql += 'DELETE FROM error_logs;'
    }
    sql += `
    ALTER TABLE news_data AUTO_INCREMENT = 1;
    ALTER TABLE news_body AUTO_INCREMENT = 1;
    ALTER TABLE news_group AUTO_INCREMENT = 1;
    ALTER TABLE news_location AUTO_INCREMENT = 1;
    ALTER TABLE channel_data AUTO_INCREMENT = 1;
    ALTER TABLE group_data AUTO_INCREMENT = 1;
    ALTER TABLE group_detail AUTO_INCREMENT = 1;
    ALTER TABLE image_data AUTO_INCREMENT = 1;
    ALTER TABLE keyword_data AUTO_INCREMENT = 1;
    ALTER TABLE relation_data AUTO_INCREMENT = 1;
    ALTER TABLE relation_keyword AUTO_INCREMENT = 1;
    ALTER TABLE error_logs AUTO_INCREMENT = 1;`

    params = []
    
    try {
        const [result] = await pool.query(sql, params);
        return res.apiSuccess(result, 'Cleaned Success');
    } catch (err) {
        err.desc = 'utils-cleanedDatabase(): cleaned database error';
        return next(err);
    }
3
});

module.exports = router