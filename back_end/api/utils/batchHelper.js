const fs = require('fs/promises');
const path = require('path');
const pool = require('../connect_db');
const { checkRequireField } = require('../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');
const { insertChannel } = require('../middlewares/channelController');

// 絕對路徑
const BASE_DIR = path.resolve(__dirname, '..', '..', 'newsCrawler');

async function batchChannel(req, res, next) {

    let { file_name, file_path=BASE_DIR } = req.body ?? {};

    // 檢查必要欄位 & 格式 - file_name
    try {
        [ file_name ] = await checkRequireField ([
            { field: 'file_name' , data: file_name , type: 'string' , other: ['non_null'] },
            { field: 'file_path' , data: file_path , type: 'string' , other: ['non_null'] }
        ]);
    } catch (err) {
        err.desc = "utils-batchChannel(): Missing or Invalid required fields";
        return next(err);
    }

    let full_path = path.resolve(file_path, String( file_name ).trim() );

    let text, data;
    try {
        text = await fs.readFile(full_path, 'utf-8');
        data = JSON.parse(text);
    } catch (err) {
        err.desc = "utils-batchChannel(): readFile failed";
        return next(err);
    }

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
    
    // 將錯誤資料存入 0_CHANNEL_ERR_DATA.json 中
    if (err_data.length!==0) {
        try {
            await saveDataToJson ( err_data, "0_CHANNEL_ERR_DATA.json" );
        } catch (err) {
            err.desc = "utils-batchChannel(): save Data To Json Error";
            return next(err);
        }
    }

    // 清空 json 中的資料
    try {
        await saveDataToJson ( null, file_name, 1 );
    } catch (err) {
        err.desc = "utils-batchChannel(): Clean Json Data Error";
        return next(err);
    }
    return res.apiSuccess({}, "Batch Insert Channel Success");
}

async function batchNews(req, res, next) {
    
}

async function saveDataToJson ( file_data, file_name = 'output.json', clean = 0, file_path = BASE_DIR ) {
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

