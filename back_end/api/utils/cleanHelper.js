const express = require('express');
const router = express.Router();
const pool = require('../connect_db')

// 清理 database
router.get('/', async (req, res, next) => {
    const { news, channel, image, err } = req.query;

    let sql = ''

    if ( news == 1 ) {
        sql += 'DELETE FROM news_data;'
    }if ( channel  == 1 ) {
        sql += 'DELETE FROM channel_data;'
    }if ( image  == 1 ) {
        sql += 'DELETE FROM image_data;'
    }if ( err  == 1 ) {
        sql += 'DELETE FROM error_logs;'
    }
    sql += `
    ALTER TABLE news_data AUTO_INCREMENT = 1;
    ALTER TABLE news_body AUTO_INCREMENT = 1;
    ALTER TABLE news_group AUTO_INCREMENT = 1;
    ALTER TABLE channel_data AUTO_INCREMENT = 1;
    ALTER TABLE group_data AUTO_INCREMENT = 1;
    ALTER TABLE group_detail AUTO_INCREMENT = 1;
    ALTER TABLE image_data AUTO_INCREMENT = 1;
    ALTER TABLE error_logs AUTO_INCREMENT = 1;`

    params = []
    
    try {
        const [result] = await pool.query(sql, params);
        return res.apiSuccess(result, 'Cleaned Success');
    } catch (err) {
        err.desc = 'utils-cleanedDatabase(): cleaned database error';
        return next(err);
    }

});

module.exports = router