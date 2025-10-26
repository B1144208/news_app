const pool = require('../connect_db');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');
const { checkRequireField } = require('../utils/checkHelper');
const { insertChannel } = require('./channelController');
const { insertImage, deleteImage } = require('./imageController');
const { insertGroup } = require('./groupController');
const { searchLocation } = require('./locationController');
const { insertRelation, deleteRelation } = require('./relationController') ;

// search
async function searchNews(req, res, next) {
    let id = req.params?.id;
    let { url, locationId, locationType } = req.query ?? {};

    // 檢查必要欄位 & 格式
    try {
        [ id, url, locationId, locationType ] = await checkRequireField ([
            { field: 'id'           , data: id           , type: 'number' , other: ['lth'] },
            { field: 'url'          , data: url          , type: 'string' , other: ['lth'] },
            { field: 'locationId'   , data: locationId   , type: 'number' , other: ['lth'] },
            { field: 'locationType' , data: locationType , type: 'string' , other: ['lth'] }
        ]);
    } catch (err) {
        err.desc = "middlewares-searchNews(): Missing or Invalid required fields";
        return next(err);
    }

    let sql = `
        SELECT
            nd.*,
            GROUP_CONCAT(DISTINCT ls.state_name_en) AS state_names,
            GROUP_CONCAT(DISTINCT lc.country_name_en) AS country_names
        FROM
            news_data AS nd
        LEFT JOIN
            news_location AS nl ON nd.news_id = nl.news_id
        LEFT JOIN
            location_states AS ls ON nl.location_state_id = ls.state_id
        LEFT JOIN
            location_countries AS lc ON nl.location_country_id = lc.country_id
        WHERE
            1
    `;
    let params = [];

    if (id) {
        sql += ` AND nd.news_id = ?`;
        params.push(id);
    }
    else if (url) {
        sql += ` AND nd.origin_url = ?`;
        params.push(url);
    }
    // 直接使用前端傳來的地點 ID 和類型
    else if (locationId) {
        if (locationType === 'state') {
            sql += ` AND nl.location_state_id = ?`;
            params.push(locationId);
        } else if (locationType === 'country') {
            sql += ` AND nl.location_country_id = ?`;
            params.push(locationId);
        } else if (locationType === 'region') {
            // 🌟 關鍵修正：添加 region 的查詢條件 🌟
            // 假設 news_location 表中 Region ID 欄位名為 location_region_id
            sql += ` AND nl.location_region_id = ?`;
            params.push(locationId);
        }
    }

    sql += ` GROUP BY nd.news_id`;

    try {
        let [result] = await pool.query(sql, params);
        return res.apiSuccess(result, 'Search Success');
    } catch (err) {
        err.desc = 'middlewares-searchNews(): database search error';
        return next(err);
    }
}

// insert
async function insertNews(req, res, next) {
    let { url, channel, cover_img, title, publish_date, detail, group, location, keyword, comment } = req.body ?? {};

    try {
        // 優先檢查 url 是否已經存在
        try {
            let fakeReq = {
                query: {
                    url: url
                }
            };
            searchNewsResult = await callAndCatchApiSuccess ( searchNews, fakeReq );
            if ( searchNewsResult.length === 1 ) {
                return res.apiSuccess ( {insertId: searchNewsResult[0].news_id}, "Search Success" );
            }
        } catch (err) {
            err.desc = "middlewares-insertNews(): database search error";
            return next(err);
        }

        // 檢查必要欄位 & 格式
        let requireFields = [
            { field: 'url'          , data: url         , type: 'string'    , other: ['non_null'] },
            { field: 'channel'      , data: channel     , type: 'string'    , other: ['non_null'] },
            { field: 'cover_img'    , data: cover_img   , type: 'image'     , other: ['lth' ]     },
            { field: 'title'        , data: title       , type: 'string'    , other: ['non_null'] },
            { field: 'publish_date' , data: publish_date, type: 'datetime'  , other: ['non_null'] },
            { field: 'detail'       , data: detail      , type: 'object'    , other: ['non_null', 'news_detail'] },
            { field: 'group'        , data: group       , type: 'array'     , other: ['string_into_array']  , array_filter: 'string' },
            { field: 'location'     , data: location    , type: 'array'     , other: ['string_into_array']  , array_filter: 'string' },
            { field: 'keyword'      , data: keyword     , type: 'array'     , other: ['string_into_array']  , array_filter: 'string' },
            { field: 'comment'      , data: comment     , type: 'array'     , other: ['string_into_array']  , array_filter: 'string' }
        ];
        try {
            let result = await checkRequireField ( requireFields );
            [ url, channel, cover_img, title, publish_date, detail, group, location, keyword ] = result;
        } catch (err) {
            err.desc = "middlewares-insertNews(): Missing or Invalid required fields";
            return next(err);
        }

        // 失敗時，刪除 news
        async function callDeleteNews ( news_id, image_id, relation_id ) {
            let fakeReq = {};
            fakeReq.params = { id: news_id };
            fakeReq.body   = { image_id: image_id, relation_id: relation_id };
            await callAndCatchApiSuccess( deleteNews, fakeReq );
        }

        // 獲取 channel_id
        let channel_id = null;
        try {
            let fakeReq = {
                body: { name: channel }
            };
            const insertChannelResult = await callAndCatchApiSuccess( insertChannel, fakeReq );
            channel_id = insertChannelResult.insertId; 
        } catch (err) {
            err.desc = 'middlewares-insertNews(): database insert error ( channel )';
            next(err)
        }

        // 獲取 img_id
        async function getImgId( imgData ) {
            if ( !imgData || !imgData.src ) return null;
            let fakeReq = {
                body: { img: imgData }
            };
            try {
                const insertImageResult = await callAndCatchApiSuccess ( insertImage, fakeReq );
                return insertImageResult.insertId;
            } catch (err) {
                err.desc = 'middlewares-insertNews(): database insert error ( img )';
                throw err;
            }
        }

        // 獲取 cover_img_id
        let image_id = []
        let cover_img_id = null;
        try {
            cover_img_id = await getImgId( cover_img );
            image_id.push( cover_img_id );
        }catch (err) {
            err.desc = 'middlewares-insertNews(): database insert error ( cover_img )';
            return next(err);
        }

        // 獲取 relation_id
        let relation_id = null;
        try {
            let fakeReq = {
                body: { keyword: keyword }
            };
            let insertRelationResult = await callAndCatchApiSuccess( insertRelation, fakeReq );
            relation_id = insertRelationResult.insertId;
        } catch(err) {
            await callDeleteNews( null, image_id, relation_id );
            err.desc = 'middlewares-insertNews(): database insert error ( relation )';
            return next(err);
        }

        // 插入資料庫
        let sql = '', params = []

        // 1. 插入 news_data ( FK: channel_id, cover_image )
        let news_id = null;
        sql = `
            INSERT INTO news_data (
                origin_url,
                channel_id,
                relation_id,
                cover_image,
                news_title,
                news_date
            ) VALUES (?, ?, ?, ?, ?, ?);
        `;
        params = [ url, channel_id, relation_id, cover_img_id, title, publish_date ];

        try {
            const [newsDataResult] = await pool.query(sql, params);
            news_id = newsDataResult.insertId;
        } catch (err) {
            await callDeleteNews( null, image_id, relation_id );
            err.desc = 'middlewares-insertNews(): database insert error ( data )';
            return next(err)
        }

        // 2. 插入 news_body
        let order = 10;
        sql = `
            INSERT INTO news_body (
                news_id,
                body_type,
                body_text,
                body_image,
                body_order
            ) VALUE
        `;
        params = [];
        for( let [index, item] of detail.entries() ) {

            let type = null;
            let text = null;
            let img_id = null;

            if ( typeof item === 'string' ) {
                type = 'text';
                text = item;

            }
            if ( typeof item === 'object' ) {
                type = 'image';
                try {
                    img_id = await getImgId( item );
                    image_id.push( img_id );
                } catch (err) {
                    await callDeleteNews( news_id, image_id, null );
                    err.desc = 'middlewares-insertNews(): database insert error ( body - img )';
                    return next(err);
                }
                
            }

            sql += (index==0)? ` ( ?, ?, ?, ?, ?)`: `, ( ?, ?, ?, ?, ?)`;
            params.push(news_id, type, text, img_id, order);
            order += 10;
        }
        try {
            let [newsBodyResult] = await pool.query(sql, params);
        } catch (err) {
            err.desc = 'middlewares-insertNews(): database insert error ( body )';
            return next(err);
        }

        // 3. 插入 news_group
        group = !group? [null]: group;
        for (let each_group of group) {
            // 查找 group_type, group_id
            let group_type = null;
            let group_id = null;
            try {
                fakeReq = {
                    body: { id: 'other', name: each_group? each_group: '其他' }
                };
                insertGroupResult = await callAndCatchApiSuccess ( insertGroup, fakeReq );
                ( {type: group_type, id: group_id } = insertGroupResult );
            } catch (err) {
                await callDeleteNews( news_id, null, null );
                console.warn('[Search Group Failed]', err.message);
            }

            // 插入 news_group
            sql = `
                INSERT INTO news_group (
                    news_id,
                    group_${group_type}_id
                ) VALUES (?, ?)
            `;
            params = [ news_id, group_id ];
            try {
                let [newsGroupResult] = await pool.query(sql, params);
            } catch (err) {
                await callDeleteNews( news_id, null, null );
                err.desc = 'middlewares-insertNews(): database insert error ( group )';
                return next(err)
            }
        }

        // 4. 插入 news_location
        if ( location ) {
            for ( let each_location of location ) {
                if ( each_location != null ) {
                    // 查找 location_type, location_id
                    let location_type = null;
                    let location_id = null;
                    try {
                        fakeReq = {
                            query: { name: each_location }
                        };
                        let searchLocationResult = await callAndCatchApiSuccess ( searchLocation, fakeReq );
                        ( {type: location_type, id: location_id } = searchLocationResult );
                    } catch (err) {
                        console.warn('[Search Location Failed]', err.message);
                    }

                    // 插入 news_location
                    if ( location_type != null ) {
                        try {
                            sql = `
                                INSERT INTO news_location (
                                    news_id,
                                    location_${ location_type }_id
                                ) VALUES (?, ?)
                            `;
                            params = [ news_id, location_id ];
                            let [newsLocationResult] = await pool.query(sql, params);
                        } catch(err) {
                            await callDeleteNews( news_id, null, null );
                            err.desc = 'middlewares-insertNews(): database insert error ( location )';
                            return next(err)
                        }
                    }
                }
            }
        }
        return res.apiSuccess({insertId: news_id}, "Insert Success");
    } catch (err) {
        await callDeleteNews ( news_id, image_id, relation_id )

        err.desc = "middlewares-insertNews: unknown error";
        return next(err);
    }

}

// update
async function updateNews(req, res, next) {
    return;
}

// delete
async function deleteNews(req, res, next) {
    let news_id = req.params?.id;
    let { image_id=null, relation_id=null } = req.body ?? {};

    // 檢查必要欄位 & 格式 - id, image_id, relation_id
    try {
        [ news_id, image_id, relation_id ] = await checkRequireField ([
            { field: 'news_id'      , data: news_id     , type: 'number' },
            { field: 'image_id'     , data: image_id    , type: 'array' , array_filter: 'number' },
            { field: 'relation_id'  , data: relation_id , type: 'number' }
        ]);
    } catch (err) {
        err.desc = "middlewares-deleteNews(): Missing or Invalid required fields";
        return next(err);
    }

    // 刪除 image, relation
    async function delete_data( image_id, relation_id) {

        // delete image
        if ( image_id ) {
            const deletionTasks = image_id.map( each_image => {
                const fakeReq = {
                    params: { id: each_image },
                    query : { has: '' }
                }
                return callAndCatchApiSuccess( deleteImage, fakeReq);
            });
            try {
                await Promise.all( deletionTasks );
            } catch (err) {
                err.desc = "middlewares-deleteNews(): database delete error - image_id"
                throw err;
            }
        }

        // delete relation
        if ( relation_id ) {
            fakeReq = {
                params: { id: relation_id },
                query : { has: '' }
            };
            try {
                await callAndCatchApiSuccess( deleteRelation, fakeReq);
            } catch (err) {
                err.desc = "middlewares-deleteNews(): database delete error - relation_id";
                throw err;
            }
        }
    }

    // 還沒生成 news_id
    try {
        await delete_data( image_id, relation_id );
    } catch (err) {
        return next(err);
    }
    
    if ( !news_id ) return res.apiSuccess({}, "Delete Success");

    // 已生成 news_id, 找 image_id 跟 relation_id
    image_id = [];
    let sql = `
        SELECT cover_image AS image_id
        FROM news_data
        WHERE news_id = ?
        AND cover_image IS NOT NULL

        UNION

        SELECT body_image AS image_id
        FROM news_body
        WHERE news_id = ?
        AND body_type = 'image'
        AND body_image IS NOT NULL;
    `;
    let params = [ news_id, news_id ];

    try {
        let [result] = await pool.query(sql, params);
        result.map( img => image_id.push( img.image_id ) );
    } catch (err) {
        err.desc = "middlewares-deleteNews(): database search error - image-_id";
        return next(err);
    }

    sql = `
        SELECT relation_id
        FROM news_data
        WHERE news_id = ?
    `;
    params = [ news_id ];
    try {
        let [result] = await pool.query(sql, params);
        relation_id = result[0]?.relation_id || null;
    } catch (err) {
        err.desc = "middlewares-deleteNews(): database search error - relation-_id";
        return next(err);
    }

    sql = `
        DELETE FROM 
            news_data 
        WHERE news_id = ?
    `;
    params = [ news_id ]
    try {
        let [result] = await pool.query(sql, params);

        // 如果沒有刪除任何資料
        if (result.affectedRows === 0) {
            let err = new Error('News not found')
            err.desc = 'middlewares-deleteNews(): News not found';
            err.status = 404;
            return next(err);
        }
    } catch (err) {
        err.desc = 'middlewares-deleteNews(): database delete error - news_id'
        return next(err)
    }
    try {
        await delete_data( image_id, relation_id );
    } catch (err) {
        return next(err);
    }
    
    return res.apiSuccess({}, "Delete Success");
}


module.exports = {
    searchNews,
    insertNews,
    updateNews,
    deleteNews
}