const pool = require('../connect_db');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');
const { checkImageFormat, formatDateTimeForSQL, checkRequireField } = require('../utils/checkHelper');
const { searchChannel, insertChannel, deleteChannel } = require('./channelController');
const { insertImage, deleteImage } = require('./imageController');
const { insertGroup } = require('./groupController');
const { searchLocation } = require('./locationController');
const { insertRelation, deleteRelation } = require('./relationController');

// search
async function searchNews(req, res, next) {
    let sql = `
        SELECT * 
        FROM news_data 
        WHERE 1
    `
    let params = []
    try {
        let [result] = await pool.query(sql, params);
        return res.apiSuccess(result, 'Search Success');
    } catch (err) {
        err.desc = 'middlewares-searchNews(): database search error'
        return next(err)
    }
}

// insert
async function insertNews(req, res, next) {
    let { url, channel, cover_img, news_title, publish_date, detail, group, location, keyword } = req.body;

    // 檢查必要欄位 & 格式
    let requireFields = [];
    requireFields.push(
        { field: 'url'          , data: url         , type: 'string'    , other: ['null'] },
        { field: 'channel'      , data: channel     , type: 'string'    , other: ['null'] },
        { field: 'cover_img'    , data: cover_img   , type: 'image'                       },
        { field: 'news_title'   , data: news_title  , type: 'string'    , other: ['null'] },
        { field: 'publish_date' , data: publish_date, type: 'datetime'  , other: ['null'] },
        { field: 'detail'       , data: detail      , type: 'object'    , other: ['null'] }
    );

    let result = await checkRequireField ( requireFields );
    { url, channel, cover_img, news_title, publish_date, detail, group, location, keyword }




    /*let missingFields = [];

    if (!url || typeof url !== 'string' || url.trim() === '') missingFields.push('url');
    if (!channel || typeof channel !== 'string' || channel.trim() === '') missingFields.push('channel');
    if (!news_title || typeof news_title !== 'string' || news_title.trim() === '') missingFields.push('news_title');
    if (!publish_date || typeof publish_date !== 'string' || publish_date.trim() === '') missingFields.push('publish_date');
    if (!detail) missingFields.push('detail');

    if (missingFields.length > 0) {
        let err = new Error('Internal Server Error');
        err.desc = `middlewares-insertNews(): Missing required fields - ${missingFields.join(', ')}`;
        err.status = 400;
        return next(err);
    }*/

    // 檢查 publish_date 格式
    /*try {
        publish_date = formatDateTimeForSQL(publish_date);
    } catch (err) {
        err.desc = 'middlewares-insertNews(): Invalid Format - publish_date ( must be DATETIME )';
        err.status = 400
        return next(err)
    }*/

    // 檢查 detail 格式
    /*if (typeof detail !== 'object' || detail === null) {
        let err = new Error('Invalid Format Error');
        err.desc = 'middlewares-insertNews(): Invalid Format - detail ( must be object )';
        err.status = 400
        return next(err)
    }*/

    // 檢查 detail 的 text, img 格式
    let cleanaedDetail = await Promise.all ( detail.map ( async item => {
        // 跳過空字串
        if ( typeof item !== 'object' || item === null ) return null;

        // 檢查 text
        if ( 'text' in item && typeof item.text === 'string' && item.text.trim() !== '') {
            return { text: item.text.trim() };
        }

        // 檢查 img
        if ('img' in item) {
            let formattedImg  = await checkImageFormat(item.img);
            if( formattedImg ) {
                return { img: formattedImg };
            }
        }
        return null;
    }));
    detail = cleanaedDetail.filter( item => item !== null );
    if ( detail.length === 0 ) {
        let err = new Error('Invalid Format Error');
        err.desc('middlewares-insertNews(): Invalid Format - detail ( error format )')
        err.status = 400;
    }

    // 檢查 cover_img 格式
    cover_img = await checkImageFormat(cover_img);

    // req.body 處理
    url = url.trim();
    channel = channel.trim();
    news_title = news_title.trim();
    publish_date = publish_date.trim();
    group = ( Array.isArray(group) )
        ? ( (group.length !== 0)
            ? (group.map( each_group => {
                return each_group = ( each_group && typeof each_group === 'string' && each_group.trim() !== '' )
                ? each_group.trim()
                : null
            })).filter( item => item !== null)
            : [null] )
        : ( ( group && typeof group === 'string' && group.trim() !== '' )
            ? [group.trim()]
            : [null] );
    if( group.length === 0 ) group = [null];

    location = ( Array.isArray(location) )
        ? ((location.length !== 0)
            ? (location.map( each_location => {
                return each_location = ( each_location && typeof each_location === 'string' && each_location.trim() !== '' )
                ? each_location.trim()
                : null
            })).filter( item => item !== null )
            : [null])
        : (( location && typeof location === 'string' && location.trim() !== '' )
            ? [location.trim()]
            : [null] );
    if( location.length === 0 ) location = [null];

    keyword = (Array.isArray(keyword))
        ? keyword.filter(item => item && typeof item === 'string' && item.trim() !== '').map(item => item.trim())
        : (keyword && typeof keyword === 'string' && keyword.trim() !== '') 
            ? [keyword.trim()]
            : [];
    

    async function callDeleteNews ( news_id, image_id, relation_id ) {
        
        let fakeReq = {
            body: {
                image_id: image_id,
                relation_id: relation_id
            }
        };

        if ( news_id ) {
            fakeReq = {
                params: {
                    id: news_id
                }
            };
        }

        await callAndCatchApiSuccess( deleteNews, fakeReq );
    }

    // 獲取 channel_id
    let channel_id = null;
    try {
        let fakeReq = {
            query: {
                name: channel
            }
        }
        const searchChannelResult = await callAndCatchApiSuccess( searchChannel, fakeReq );
        channel_id = searchChannelResult.searchId; 
    } catch (err) {
        //console.warn('[Search Channel Failed]', err.message);
    }
    if ( !channel_id ) {
        try {
            let fakeReq = {
                body: {
                    name: channel
                }
            }
            const insertChannelResult = await callAndCatchApiSuccess( insertChannel, fakeReq );
            channel_id = insertChannelResult.insertId; 
        } catch (err) {
            err.desc = 'middlewares-insertNews(): database insert error ( channel )';
            next(err)
        }
    }

    // 獲取 img_id
    async function getImgId( imgData ) {

        if ( !imgData || !imgData.src ) return null;

        let fakeReq = {
            body: {
                src: imgData.src,
                alt: imgData.alt || null
            }
        }
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
            body: {
                keyword: keyword
            }
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
    params = [ url, channel_id, relation_id, cover_img_id, news_title, publish_date ]

    try {
        const [newsDataResult] = await pool.query(sql, params);
        news_id = newsDataResult.insertId
    } catch (err) {
        await callDeleteNews( null, image_id, relation_id );
        err.desc = 'middlewares-insertNews(): database insert error ( data )';
        return next(err)
    }

    // 2. 插入 news_body
    let order = 10;
    for( let item of detail ) {

        let type = null;
        let text = null;
        let img_id = null;

        if ( 'text' in item ) {
            type = 'text';
            text = item.text;

        }
        if ('img' in item ) {
            type = 'image';
            try {
                img_id = await getImgId( item.img );
                image_id.push( img_id );
            } catch (err) {
                await callDeleteNews( null, image_id, relation_id );
                err.desc = 'middlewares-insertNews(): database insert error ( body - img )';
                return next(err);
            }
            
        }

        sql = `
            INSERT INTO news_body (
                news_id,
                body_type,
                body_${type==='text'? 'text': 'image'},
                body_order
            ) VALUE ( ?, ?, ?, ?)
        `
        params = [ news_id, type, text || img_id, order]
        
        try {
            let [newsBodyResult] = await pool.query(sql, params);
        } catch (err) {
            err.desc = 'middlewares-insertNews(): database insert error ( body )';
            return next(err)
        }
        order += 10;
    }
    // res.apiSuccess( { insertId: news_id }, 'Insert news_body Success' );

    // 3. 插入 news_group
    
    for (let each_group of group) {
        // 查找 group_type, group_id
        let group_type = null;
        let group_id = null;
        try {
            fakeReq = {
                body: {
                    id: 'other',
                    name: each_group? each_group: '其他'
                }
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
            res.apiSuccess({ insertId: newsGroupResult.insertId }, 'Insert Success')
        } catch (err) {
            await callDeleteNews( news_id, null, null );
            err.desc = 'middlewares-insertNews(): database insert error ( group )';
            return next(err)
        }
    }

    // 4. 插入 news_location
    for ( let each_location of location ) {
        if ( each_location != null ) {
            // 查找 location_type, location_id
            let location_type = null;
            let location_id = null;
            try {
                fakeReq = {
                    query: {
                        name: each_location
                    }
                };
                searchLocationResult = await callAndCatchApiSuccess ( searchLocation, fakeReq );
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
    
    // 插入 keyword 到 relation_data


}

// update
async function updateNews(req, res, next) {
    return;
}

// delete
async function deleteNews(req, res, next) {
    const id = req.params?.id || null;
    let { image_id, relation_id } = req.body || { image_id: null, relation_id: null };

    // 檢查必要欄位
    if ( !id ) {
        
        const hasImageId = Object.prototype.hasOwnProperty.call(req.body, 'image_id');
        const hasRelationId = Object.prototype.hasOwnProperty.call(req.body, 'relation_id');

        if (!hasImageId || !hasRelationId) {
            const err = new Error('Missing required fields');
            err.desc = 'middlewares-deleteNews(): Missing required fields - ( image_id & relation_id )';
            err.status = 400;
            return next(err);
        }
    }

    // 檢查 id 是否有效
    if ( id && isNaN(id)) {
        let err = new Error('Invalid Number Error');
        err.desc = 'middlewares-deleteNews(): Missing or Invalid required fields - news_id';
        err.status = 400;
        return next(err);
    }

    // 刪除 image, relation
    async function delete_data( image_id, relation_id) {

        // delete image
        if ( image_id ) {
            const validImageIds = image_id.filter( Boolean ).filter( each_image => !isNaN(each_image) );
            const deletionTasks = validImageIds.map( each_image => {
                const fakeReq = {
                    params: {
                        id: each_image
                    },
                    query: {
                        has: ''
                    }
                }
                return callAndCatchApiSuccess( deleteImage, fakeReq);
            });
            try {
                await Promise.all(deletionTasks)
            } catch (err) {
                err.desc = "middlewares-deleteNews(): database delete error - image_id"
                return next(err);
            }
        }

        // delete relation
        if ( relation_id ) {
            fakeReq = {
                params: {
                    id: relation_id
                },
                query: {
                    has: ''
                }
            };
            try {
                await callAndCatchApiSuccess( deleteRelation, fakeReq);
            } catch (err) {
                err.desc = "middlewares-deleteNews(): database delete error - relation_id";
                return next(err);
            }
        }
        return ;
    }
    // 還沒生成 news_id
    if ( !id ) {
        delete_data( image_id, relation_id );
        return res.apiSuccess({}, "Delete Success");
    }

    // 已生成 news_id
    // 找 image_id 跟 relation_id
    image_id = [];
    let sql = `
        SELECT cover_image, body_type, body_image, relation_id
        FROM news_data
        NATURAL JOIN news_body
        WHERE news_id=?;
    `;
    let params = [ id ]

    try {
        let [result] = await pool.query(sql, params);
        if ( result[0].cover_image ) image_id.push( result[0].cover_image );
        if ( result[0].relation_id ) relation_id = result[0].relation_id;
        result.map( body => {
            if(body.body_type = 'img') image_id.push( body.body_image );
        })
    } catch (err) {
        err.desc = "middlewares-deleteNews(): database search error - image-_id, relation_id";
        next(err);
    }

    sql = `
        DELETE FROM 
            news_data 
        WHERE news_id = ?
    `;
    params = [ id ]
    try {
        let [result] = await pool.query(sql, params);

        // 如果沒有刪除任何資料
        if (result.affectedRows === 0) {
            let err = new Error('News not found')
            err.desc = 'middlewares-deleteNews(): News not found';
            err.status = 404;
            return next(err);
        }

        res.apiSuccess( null, 'Delete Success' )
    } catch (err) {
        err.desc = 'middlewares-deleteNews(): database delete error - news_id'
        return next(err)
    }
    delete_data( image_id, relation_id );
    return res.apiSuccess({}, "Delete Success");
}


module.exports = {
    searchNews,
    insertNews,
    updateNews,
    deleteNews
}