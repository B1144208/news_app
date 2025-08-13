const express = require('express');
const router = express.Router();
const pool = require('../connect_db')

// 清理 database
router.get('/', async (req, res, next) => {

    const user      = 'user'        in req.query;

    const news      = 'news'        in req.query;
    const channel   = 'channel'     in req.query;
    const group     = 'group'       in req.query;
    const image     = 'image'       in req.query;
    const keyword   = 'keyword'     in req.query;
    const relation  = 'relation'    in req.query;
    const error     = 'error'       in req.query;

    let sql = ''

    // 刪除資料
    user        &&  ( sql += 'DELETE FROM user_profile;'                            );
    
    news        &&  ( sql += 'DELETE FROM news_data;'                               );
    channel     &&  ( sql += 'DELETE FROM channel_data;'                            );
    group       &&  ( sql += 'DELETE FROM group_data   WHERE group_id > 15;'        );
    group       &&  ( sql += 'DELETE FROM group_detail WHERE group_detail_id > 66;' );
    image       &&  ( sql += 'DELETE FROM image_data;'                              );
    keyword     &&  ( sql += 'DELETE FROM keyword_data;'                            );
    relation    &&  ( sql += 'DELETE FROM relation_data;'                           );

    error       &&  ( sql += 'DELETE FROM error_logs;'                              );

    // AUTO 重置
    sql += `
    ALTER TABLE user_profile AUTO_INCREMENT = 1;

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

    params = [];
    
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