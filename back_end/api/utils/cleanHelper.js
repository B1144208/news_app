const express = require('express');
const router = express.Router();
const pool = require('../connect_db')

// 清理 database

module.exports = async ( req, res, next ) => {

    let whole_user  = 'whole_user'  in req.query; // user, favorite, anonymous, action
    let user        = 'user'        in req.query;
    let favorite    = 'favorite'    in req.query;
    let anonymous   = 'anonymous'   in req.query;

    let action      = 'action'      in req.query; // view, comment, bookmark, share, score, search
    let view        = 'view'        in req.query;
    let comment     = 'comment'     in req.query;
    let bookmark    = 'bookmark'    in req.query;
    let share       = 'share'       in req.query;
    let score       = 'score'       in req.query;
    let search      = 'search'      in req.query;

    let whole_news  = 'whole_news'  in req.query; // news, channel, group, image, keyword, relation
    let news        = 'news'        in req.query;
    let channel     = 'channel'     in req.query;
    let group       = 'group'       in req.query;
    let image       = 'image'       in req.query;
    let keyword     = 'keyword'     in req.query;
    let relation    = 'relation'    in req.query;
    let event       = 'event'       in req.query;
    let multiple    = 'multiple'    in req.query;

    const value     = 'value'       in req.query;
    const error     = 'error'       in req.query;

    let sql = ''

    // 刪除資料
    if (whole_user) { user =  favorite = anonymous = action = true;                     }
    user        &&  ( sql += 'DELETE FROM user_profile;'                                );
    favorite    &&  ( sql += 'DELETE FROM user_favorite;'                               );
    anonymous   &&  ( sql += 'DELETE FROM user_anonymous; DELETE FROM anonymous_data;'  );

    if (action)     { view =  comment = bookmark = share = score = search = recent = true;       }
    view        &&  ( sql += 'DELETE FROM user_view;'                                   );
    comment     &&  ( sql += 'DELETE FROM user_comment;'                                );
    bookmark    &&  ( sql += 'DELETE FROM user_bookmark;'                               );
    share       &&  ( sql += 'DELETE FROM user_share;'                                  );
    score       &&  ( sql += 'DELETE FROM user_score;'                                  );
    search      &&  ( sql += 'DELETE FROM user_search_record; DELETE FROM user_search;' );
    recent      &&  ( sql += 'DELETE FROM recent_action;'                               );
    
    if (whole_news) { news =  channel = group = image = keyword = relation = event = multiple = true;}
    news        &&  ( sql += 'DELETE FROM news_data;'                                   );
    channel     &&  ( sql += 'DELETE FROM channel_data;'                                );
    group       &&  ( sql += 'DELETE FROM group_data   WHERE group_id > 15;'            );
    group       &&  ( sql += 'DELETE FROM group_detail WHERE group_detail_id > 66;'     );
    image       &&  ( sql += 'DELETE FROM image_data;'                                  );
    keyword     &&  ( sql += 'DELETE FROM keyword_data; DELETE FROM keyword_relation;'  );
    relation    &&  ( sql += 'DELETE FROM relation_data; DELETE FROM relation_keyword;' );
    event       &&  ( sql += 'DELETE FROM eventsorting_data;'                           );
    multiple    &&  ( sql += 'DELETE FROM multipleperspectives_data;'                   );

    value       &&  ( sql += 'DELETE FROM value_adjust;'                                );
    error       &&  ( sql += 'DELETE FROM error_logs;'                                  );

    // AUTO 重置
    sql += `
        ALTER TABLE user_profile AUTO_INCREMENT = 1;
        ALTER TABLE user_favorite AUTO_INCREMENT = 1;
        ALTER TABLE user_anonymous AUTO_INCREMENT = 1;
        ALTER TABLE anonymous_data AUTO_INCREMENT = 1;
        ALTER TABLE user_view AUTO_INCREMENT = 1;
        ALTER TABLE user_comment AUTO_INCREMENT = 1;
        ALTER TABLE user_bookmark AUTO_INCREMENT = 1;
        ALTER TABLE user_share AUTO_INCREMENT = 1;
        ALTER TABLE user_score AUTO_INCREMENT = 1;
        ALTER TABLE user_search AUTO_INCREMENT = 1;
        ALTER TABLE user_search_record AUTO_INCREMENT = 1;

        ALTER TABLE news_data AUTO_INCREMENT = 1;
        ALTER TABLE news_body AUTO_INCREMENT = 1;
        ALTER TABLE news_group AUTO_INCREMENT = 1;
        ALTER TABLE news_location AUTO_INCREMENT = 1;
        ALTER TABLE channel_data AUTO_INCREMENT = 1;
        ALTER TABLE group_data AUTO_INCREMENT = 1;
        ALTER TABLE group_detail AUTO_INCREMENT = 1;
        ALTER TABLE image_data AUTO_INCREMENT = 1;
        ALTER TABLE keyword_data AUTO_INCREMENT = 1;
        ALTER TABLE keyword_relation AUTO_INCREMENT = 1;
        ALTER TABLE relation_data AUTO_INCREMENT = 1;
        ALTER TABLE relation_keyword AUTO_INCREMENT = 1;
        ALTER TABLE eventsorting_data AUTO_INCREMENT = 1;
        ALTER TABLE multipleperspectives_data AUTO_INCREMENT = 1;

        ALTER TABLE error_logs AUTO_INCREMENT = 1;
    `
    params = [];
    
    try {
        const [result] = await pool.query(sql, params);
        return res.apiSuccess(result, 'Cleaned Success');
    } catch (err) {
        err.desc = 'utils-cleanedDatabase(): cleaned database error';
        return next(err);
    }
}
