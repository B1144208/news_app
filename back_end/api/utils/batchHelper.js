//const os = require('os');
const fs = require('fs/promises');
const path = require('path');
const pool = require('../connect_db');

const { checkRequireField } = require('../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');
const { insertChannel } = require('../middlewares/channelController');
const { insertNews } = require('../middlewares/newsController');

// CRAWLER 絕對路徑
const CURRENT_DIR = __dirname;
const BACKEND_DIR = path.resolve(CURRENT_DIR, '..', '..');  // utils -> api -> back_end
require('dotenv').config({path: path.resolve(BACKEND_DIR, '.env')});
const CRAWLER_PATH = path.resolve( BACKEND_DIR, process.env.CRAWLER_DATA_PATH);


async function batchNews(req, res, next) {
    let { data } = req.body ?? {};

    // 檢查必要欄位 & 格式 - file_name
    try {
        [ data ] = await checkRequireField ([
            { field: 'data'     , data: data        , type: 'array' }
        ], "utils-batchChannel()");
    } catch (err) {
        return next(err);
    }

    console.log("batchHelper_0:", data);

    if ( data == null )
        return res.apiSuccess({}, "Batch Insert News Success");

    // ai 生成 group, location, keyword
    // ------------------------------------------------------------------------------------------------------------
    
    // 儲存錯誤資料
    let err_data = [];
    for ( let i=0; data[i]; i++) {
        try {
            let fakeReq = {
                body: {
                    url: data[i].url,
                    channel: data[i].channel,
                    cover_img: data[i].cover_img || null,
                    title: data[i].title || data[i].news_title, // -------------------------------------------
                    publish_date: data[i].publish_date,
                    detail: data[i].detail,
                    group: data[i].group || null,
                    location: data[i].location || null,
                    keyword: data[i].keyword || null,
                    comment: data[i].comment || null,
                }
            }
            let insertNewsResult = await callAndCatchApiSuccess ( insertNews, fakeReq );
        } catch (err) {
            err_data.push(data[i]);
        }
    }

    // 將錯誤資料存入 ERR_NEWS_DATA.json 中
    if (err_data.length!==0) {
        try {
            await saveDataToJson ( err_data, process.env.CRAWLER_ERR_NEWS_FILE );
        } catch (err) {
            err.desc = "utils-batchChannel(): save Error Data To Json Error";
            return next(err);
        }
    }
    return res.apiSuccess({}, "Batch Insert News Success");
}

async function batchChannel(req, res, next) {

    let { data } = req.body ?? {};

    // 檢查必要欄位 & 格式 - file_name
    try {
        [ data ] = await checkRequireField ([
            { field: 'data'     , data: data        , type: 'array' }
        ], "utils-batchChannel()");
    } catch (err) {
        return next(err);
    }

    if ( data == null )
        return res.apiSuccess({}, "Batch Insert News Success");

    // 儲存錯誤資料
    let err_data = [];
    for ( let i=0; data[i]; i++) {
        try {
            let fakeReq = {
                body: {
                    url: data[i].url || null,
                    img: data[i].img || null,
                    name: data[i].name,
                    type: data[i].type || null,
                    introduce: String(data[i].introduce).trim() || null
                }
            }
            let insertChannelResult = await callAndCatchApiSuccess ( insertChannel, fakeReq );
        } catch (err) {
            err_data.push(data[i]);
        }
    }
    
    // 將錯誤資料存入 ERR_CHANNEL_DATA.json 中
    if (err_data.length!==0) {
        try {
            await saveDataToJson ( err_data, process.env.CRAWLER_ERR_CHANNEL_FILE );
        } catch (err) {
            err.desc = "utils-batchChannel(): save Error Data To Json Error";
            return next(err);
        }
    }
    return res.apiSuccess({}, "Batch Insert News Success");
}

async function saveDataToJson ( file_data, file_name = 'output.json', clean = 0, file_path = CRAWLER_PATH ) {
    const full_path = path.resolve( file_path, String( file_name ).trim());

    // 確保目錄存在
    await fs.mkdir( file_path, {recursive: true});

    // 讀取既有資料
    let data = [];
    try {
        const raw = await fs.readFile(full_path, 'utf-8');
        const parsed = JSON.parse(raw);
        if ( Array.isArray(parsed) ) data = parsed;
        if ( clean ) data = [];
    } catch (err) {
        // ENOET: 檔案不存在, SyntaxError: 格式錯誤，都重建為 []
        if ( err.code !== 'ENOET' && !(err instanceof SyntaxError )) data = [];
    }

    // 附加資料
    let added = 0;
    if (file_data==null) file_data = [];
    if ( Array.isArray(file_data)) {
        data.push(...file_data);
        added = file_data.length;
    } else if ( file_data != null ) {
        data.push(file_data);
        added = 1;
    }

    // 寫回
    if (data) await fs.writeFile(full_path, JSON.stringify(data, null, 2), 'utf-8');

    console.log(`✅ 已新增 ${added} 篇資料到 ${file_name}（目前共 ${data.length} 篇資料）`);
    return;
}

module.exports = {
    batchChannel,
    batchNews
};

