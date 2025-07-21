const pool = require('../connect_db');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');
const { checkImageFormat, formatDateTimeForSQL } = require('../utils/checkHelper');
const { searchChannel, insertChannel } = require('./channelController');
const { searchImage, insertImage } = require('./imageController');
const { searchGroup } = require('./groupController');

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
    let { url, channel, cover_img, news_title, publish_date, detail, group, location } = req.body;

    // 檢查必要欄位
    if ( (!url||url.trim() === '') || (!channel||channel.trim() === '') || (!news_title||news_title.trim() === '') || (!publish_date||publish_date.trim() === '') || (!detail) ) {
        let err = new Error('Internal Server Error')
        err.desc = `middlewares-insertNews(): Missing required fields - ${
            [
                ( !url || url.trim() === '' ) && 'url',
                ( !channel || channel.trim() === '' ) && 'channel',
                ( !news_title || news_title.trim() === '' ) && 'news_title',
                ( !publish_date || publish_date.trim() === '' ) && 'publish_date',
                ( !detail || detail.trim() === '' ) && 'detail'
            ]
            .filter(Boolean)
            .join(', ')
        }`;
        err.status = 400
        return next(err)
    }

    // 檢查 publish_date 格式
    try {
        publish_date = formatDateTimeForSQL(publish_date);
    } catch (err) {
        err.desc = 'middlewares-insertNews(): Invalid Format - publish_date ( must be DATETIME )';
        err.status = 400
        return next(err)
    }

    // 檢查 detail 格式
    if (typeof detail !== 'object' || detail === null) {
        let err = new Error('Invalid Format Error');
        err.desc = 'middlewares-insertNews(): Invalid Format - detail ( must be object )';
        err.status = 400
        return next(err)
    }

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

    // res.body 處理
    url = url.trim();
    channel = channel.trim();
    news_title = news_title.trim();
    publish_date = publish_date.trim();
    group = ( !group || group.trim() === '' )? null: group.trim();
    //location = location.trim();
    

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
        console.warn('[Search Channel Failed]', err.message);
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
            err.desc = 'middlewares-insertNews(): channel insert error';
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
            next(err);
            return null
        }
    }

    // 獲取 cover_img_id
    let cover_img_id;
    try {
        cover_img_id = await getImgId( cover_img )
    }catch (err) {
        err.desc = 'middlewares-insertNews(): database insert error ( cover_img )';
        return next(err);
    }
    

    // 插入資料庫
    let sql = '', params = []

    // 插入 news_data ( FK: channel_id, cover_image )
    let news_id = null;
    sql = `
        INSERT INTO news_data (
            channel_id,
            news_url,
            cover_image,
            news_title,
            news_date
        ) VALUES (?, ?, ?, ?, ?);
    `;
    params = [ channel_id, url, cover_img_id, news_title, publish_date ]

    try {
        const [newsDataResult] = await pool.query(sql, params);
        news_id = newsDataResult.insertId
        //res.apiSuccess({ insertId: news_id }, 'Insert Success')
    } catch (err) {
        err.desc = 'middlewares-insertNews(): database insert error ( data )';
        return next(err)
    }

    // 插入 news_body
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
            } catch (err) {
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
            await pool.query(sql, params);
        } catch (err) {
            err.desc = 'middlewares-insertNews(): database insert error ( body )';
            return next(err)
        }
        order += 10;
    }
    // res.apiSuccess( { insertId: news_id }, 'Insert news_body Success' );

    // 插入 news_group
    // 1. 查找 group_type, group_id
    let group_type = null;
    let group_id = null;
    let searchGroupResult;
    try {
        fakeReq = {
            body: {
                id: 'other',
                name: group? group: '其他'
            }
        };


        searchGroupResult = await callAndCatchApiSuccess ( insertGroup, fakeReq );


        


        ( {type: group_type, id: group_id } = searchGroupResult );
    } catch (err) {
        console.warn('[Search Group Failed]', err.message);
        
    }

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        console.log('searchGroupResult 👉', searchGroupResult);
        if (!searchGroupResult || !searchGroupResult.type || !searchGroupResult.id) {
            throw new Error('Not Found Group');
        }


    // 2. 插入 news_group
    sql = `
        INSERT INTO news_group (
            group_type,
            group_id
        ) VALUES (?, ?)
    `;
    params = [ group_type, group_id ];
    try {
        let [newsGroupResult] = await pool.query(sql, params);
        // res.apiSuccess({ insertId: newsGroupResult.insertId }, 'Insert Success')
    } catch (err) {
        err.desc = 'middlewares-insertNews(): database insert error ( group )';
        return next(err)
    }

    // 插入 news_location

    // 插入 keyword 到 relation_data


}



// update
async function updateNews(req, res, next) {
    return;
}

// delete
async function deleteNews(req, res, next) {
    const id = req.params.id;

    // 檢查 id 是否有效
    if (!id || isNaN(id)) {
        let err = new Error('Invalid Number Error');
        err.desc = 'middlewares-deleteNews(): Missing or Invalid required fields - news_id';
        err.status = 400;
        return next(err);
    }

    let sql = `
        DELETE FROM 
            news_data 
        WHERE news_id = ?
    `;
    let params = [ id ]
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
        err.desc = 'middlewares-deleteNews(): database delete error'
        return next(err)
    }
}


module.exports = {
    searchNews,
    insertNews,
    updateNews,
    deleteNews
}