const pool = require('../connect_db');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');
const { checkRequireField } = require('../utils/checkHelper');
const { insertChannel } = require('./channelController');
const { insertImage, deleteImage } = require('./imageController');
const { insertGroup } = require('./groupController');
const { searchLocation } = require('./locationController');
const { insertRelation, deleteRelation } = require('./relationController');
const { getEmbedding, findNewsRelationId } = require('../utils/embeddingHelper');

// search
async function searchNews(req, res, next) {
    let { mode, order, limit } = req.query || {}
    let { id, url, keyword, groupId, groupType, locationId, locationType } = req.body ?? {};

    // 檢查必要欄位 & 格式
    try {
        [ mode, order, limit, id, url, keyword, groupId, groupType, locationId, locationType ] = await checkRequireField ([
            { field: 'mode'         , data: mode         , type: 'string' , other: ['non_null'                ] , enum: ['id', 'simple', 'complex'] , default: 'simple'},
            { field: 'order'        , data: order        , type: 'string' , other: ['non_null'                ] , enum: ['general', 'heat', 'latest', 'view', 'share', 'search', 'bookmark', 'comment'] , default: 'general'},
            { field: 'limit'        , data: limit        , type: 'number' , other: ['non_null'                ] , default: 300                        },
            { field: 'id'           , data: id           , type: 'array'  , other: ['lth', 'number_into_array'] , array_filter: "number"              },
            { field: 'url'          , data: url          , type: 'string' , other: ['lth'                     ]                                       },
            { field: 'keyword'      , data: keyword      , type: 'array'  , other: ['lth', 'string_into_array'] , array_filter: "string"              },
            { field: 'groupId'      , data: groupId      , type: 'number' , other: ['lth'                     ]                                       },
            { field: 'groupType'    , data: groupType    , type: 'string' , other: ['lth'                     ] , enum: ['data', 'detail']            },
            { field: 'locationId'   , data: locationId   , type: 'number' , other: ['lth'                     ]                                       },
            { field: 'locationType' , data: locationType , type: 'string' , other: ['lth'                     ] , enum: ['region', 'country', 'state']}
        ]);
    } catch (err) {
        err.desc = "middlewares-searchNews(): Missing or Invalid required fields";
        return next(err);
    }

    // 優先檢查 url
    if ( url ) {
        let sql = `
            SELECT news_id
            FROM news_data
            WHERE origin_url = ?
        `;
        let params = [url];
        try {
            let [result] = await pool.query(sql, params);
            return res.apiSuccess(result, "Search Success");
        } catch (err) {
            err.desc = "middlewares-searchNews(): database search error";
            return next(err);
        }
    }

    // 選擇模式
    let searchMode = "general";
    if ( id ) searchMode = "id";
    else if ( keyword ) searchMode = "keyword";
    else if ( groupId && groupType ) searchMode = "group";
    else if ( locationId && locationType) searchMode = "location";

    let idList = [];
    let sql = null;
    let params = [];
    
    // 1. 統一查詢 idList
    // general : 直接查找 [ news 主頁 ]
    if ( searchMode == "general" ) {
        sql = `
            SELECT nd.news_id
            FROM news_data nd
            WHERE 1
        `;
        params = [];
        
    }
    // id : 直接查找 id
    if ( searchMode == "id" ) {
        idList = id;
    }
    // keyword : 查找 關鍵字 [ search 使用 ]
    // ------------- 增加 keyword_relation 查詢 ------------------------------------------------------------------------------
    if ( searchMode == "keyword" ) {
        // 分值
        const W = { title: 5, keyword: 3, body: 2, image: 1 };
        const perKwScore =
            `( (nd.news_title LIKE ?) * ${W.title} ) +` +
            ` ( COALESCE(kd.keyword_text LIKE ?, 0) * ${W.keyword} ) +` +
            ` ( COALESCE(nb.body_text    LIKE ?, 0) * ${W.body} ) +` +
            ` ( COALESCE(id.image_text   LIKE ?, 0) * ${W.image} )`;

        // 多關鍵字的總分：各關鍵字的分數相加
        const scoreSql = keyword.map(() => perKwScore).join(' + ');

        sql = `
            SELECT
            nd.news_id,
            ${scoreSql} AS score
            FROM news_data nd
            LEFT JOIN news_body        nb ON nb.news_id     = nd.news_id
            LEFT JOIN image_data       id ON id.image_id    = nb.body_image
            LEFT JOIN relation_keyword rk ON rk.relation_id = nd.relation_id
            LEFT JOIN keyword_data     kd ON kd.keyword_id  = rk.keyword_id
            GROUP BY nd.news_id
            HAVING score > 0
            ORDER BY score DESC, MAX(nd.news_date) DESC
            
        `;
        params = keyword.flatMap(k => {
            const v = `%${k}%`;
            return [v, v, v, v];
        });
    }
    // group : 查找 news_group
    if ( searchMode == "group" ) {
        sql = `
            SELECT nd.news_id
            FROM news_data nd
            JOIN news_group ng USING (news_id)
            WHERE ng.group_${groupType}_id = ?
        `;
        params = [groupId];
    }
    // location : 查找 news_location
    if ( searchMode == "location" ) {
        sql = `
            SELECT nd.news_id
            FROM news_data nd
            JOIN news_location nl USING (news_id)
            WHERE nl.location_${locationType}_id = ?
        `;
        params = [locationId];
    }

    // ORDER
    let ORDER_SQL = null;
    if (order=="general") {

    }
    else if (order=="heat") { ORDER_SQL = `ORDER BY nd.total_heat DESC`; }
    else if (order=="latest") { ORDER_SQL = `ORDER BY nd.created_at DESC`; }
    else { ORDER_SQL = `ORDER BY nd.total_recent_${order} DESC`; }


    if ( searchMode != "id" ) {
        if (ORDER_SQL) sql += (ORDER_SQL + '\n');
        sql += `LIMIT ?`;
        params.push(limit);
        try {
            let [result] = await pool.query(sql, params);
            idList = result.map(o => o?.news_id).filter(v => v != null).map(Number);
        } catch (err) {
            err.desc = 'middlewares-searchNews(): database search error ( idList Search )';
            return next(err);
        }
    }

    if ( !idList || idList.length == 0 ) return res.apiSuccess([], "Search Success");
    if ( mode == "id" ) return res.apiSuccess({idList: idList}, "Search Success");

    // 2. 選擇 simple / complex , 用 idLList 查詢
    
    // SIMPLE
    let simpleList = [];
    const ph = idList.map(() => '?').join(',');
    sql = `
        SELECT 
            nd.news_id   AS newsId,
            cd.channel_name AS channelName,
            id.image_origin_url AS coverImageUrl,
            id.image_text AS coverImageAlt,
            nd.news_title AS newsTitle,
            nd.news_date  AS publishDate,
            nd.news_url   AS newsUrl
        FROM news_data nd
            JOIN channel_data cd USING (channel_id)
            LEFT JOIN image_data id ON nd.cover_image = id.image_id
        WHERE nd.news_id IN (${ph})
        ORDER BY FIELD(nd.news_id, ${ph})
    `;
    params = [...idList, ...idList];
    //params.push(idList);
    
    // ORDER
    //if ( searchMode=="id" && ORDER_SQL ) sql += ( ORDER_SQL + '\n' );

    try {
        let [result] = await pool.query(sql, params);
        simpleList = result;
        if (mode == "simple")
            return res.apiSuccess({simpleList: simpleList}, "Search Success");
    } catch (err) {
        err.desc = 'middlewares-searchNews(): database search error ( simpleList search )';
        return next(err);
    }

    // COMPLEX
    let complexList = simpleList;
    
    // news_body
    sql = `
        SELECT 
            nb.news_id,
            nb.body_type,
            nb.body_text,
            nb.body_order,
            id.image_origin_url,
            id.image_text
        FROM news_body AS nb
        LEFT JOIN image_data AS id
            ON id.image_id = nb.body_image
        WHERE nb.news_id IN (?)
        ORDER BY nb.news_id, nb.body_order;
    `;
    params = [ idList ];
    const bodyGrouped = {};
    try {
        let [result] = await pool.query(sql, params);

        result.forEach(r => {
            if (!bodyGrouped[r.news_id]) bodyGrouped[r.news_id] = [];
            bodyGrouped[r.news_id].push(r);
        });
    }  catch (err) {
        err.desc = 'middlewares-searchNews(): database search error ( complexList search - body )';
        return next(err);
    }

    // news_location
    sql = `
        SELECT 
            nl.news_id,
            nl.location_region_id,
            lr.region_name_en AS region_name_en,
            lr.region_name_zh_tw AS region_name_zh_tw,
            nl.location_country_id,
            lc.country_name_en AS country_name_en,
            lc.country_name_zh_tw AS country_name_zh_tw,
            nl.location_state_id,
            ls.state_name_en AS state_name_en,
            ls.state_name_zh_tw AS state_name_zh_tw
        FROM news_location nl
        LEFT JOIN location_regions lr ON nl.location_region_id = lr.region_id
        LEFT JOIN location_countries lc ON nl.location_country_id = lc.country_id
        LEFT JOIN location_states ls ON nl.location_state_id = ls.state_id
        WHERE nl.news_id IN (?);
    `;
    const locationGrouped = {};
    try {
        let [rows] = await pool.query(sql, params);

        rows.forEach(r => {
            if (!locationGrouped[r.news_id]) locationGrouped[r.news_id] = [];

            if (r.location_region_id) {
                locationGrouped[r.news_id].push({
                    locationId: r.location_region_id,
                    locationType: 'region',
                    locationNameEn: r.region_name_en,
                    locationNameZh: r.region_name_zh_tw
                });
            }
            if (r.location_country_id) {
                locationGrouped[r.news_id].push({
                    locationId: r.location_country_id,
                    locationType: 'country',
                    locationNameEn: r.country_name_en,
                    locationNameZh: r.country_name_zh_tw
                });
            }
            if (r.location_state_id) {
                locationGrouped[r.news_id].push({
                    locationId: r.location_state_id,
                    locationType: 'state',
                    locationNameEn: r.state_name_en,
                    locationNameZh: r.state_name_zh_tw
                });
            }
        });

    } catch (err) {
        err.desc = 'middlewares-searchNews(): database search error ( complexList search - location )';
        return next(err);
    }

    // 寫入 complexList
    complexList = complexList.map(item => {
        const newsId = item.newsId;
        const bodys = bodyGrouped[newsId] || [];
        const locs = locationGrouped[newsId] || [];

        const newsBody = bodys
            .map(r => {
                if (r.body_type === 'image') {
                    if (!r.image_origin_url) return null;
                    return {
                        img: {
                            src: r.image_origin_url,
                            alt: r.image_text || ''
                        }
                    };
                }
                return { text: r.body_text || '' };
            })
            .filter(Boolean);

        return {
            ...item,
            newsBody,
            newsLocation: locs
        };
    });

    return res.apiSuccess({complexList: complexList}, "Search Success");
}

async function insertNews(req, res, next) {
    let { url, channel, cover_img, title, publish_date, detail, group, location, keyword, comment } = req.body ?? {};
    let news_id = image_id = relation_id = null; // 重新初始化 relation_id 為 null
    try {
        // 優先檢查 url 是否已經存在
        try {
            let fakeReq = {
                body: {
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
        async function callDeleteNews ( news_id = null, image_id = null, relation_id = null ) {
            if (news_id==null && image_id==null && relation_id == null) return;
            let fakeReq = {
                params: { id: news_id },
                body: {
                    mage_id: image_id,
                    relation_id: relation_id
                }
            }
            await callAndCatchApiSuccess( deleteNews, fakeReq );
            return;
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

        // 【此處移除原有的 relation_id 預先創建邏輯】

        // 獲取 news_embedding
        // 確保 detail 是陣列，並且包含 text 內容
        let totalText = title + (Array.isArray(detail) ? detail.map(item => item.text || (typeof item === 'string' ? item : '')).join('\n') : '');
        let embedding;
        try {
            embedding = await getEmbedding(totalText);
        } catch (err) {
            err.desc = "middlewares-insertNews(): ollama use error ( embedding )";
            // 由於 embedding 失敗，後續無法判斷 relation，但其他流程可能仍可繼續，這裡選擇中斷以確保資料完整性。
            return next(err);
        }

        const embeddingJson = JSON.stringify(embedding);
        const SIMILARITY_THRESHOLD = 0.85;

        // 【💡 增加 relation_id 判斷邏輯 - 整合查詢、比對、創建 💡】

        // 1. 查詢所有 Eventsorting Embedding (作為比對目標)
        let allEventsortingEmbeddings = [];
        try {
            const sql = `
                SELECT
                    eventsorting_id AS relation_id,
                    eventsorting_embedding
                FROM eventsorting_data
                WHERE eventsorting_embedding IS NOT NULL
                AND eventsorting_embedding <> '';
            `;
            const [rows] = await pool.query(sql);

            // 將 JSON 字串解析為 number[] 向量
            allEventsortingEmbeddings = rows.map(row => {
                let eventEmbedding;
                try {
                    eventEmbedding = JSON.parse(row.eventsorting_embedding);
                } catch (e) {
                    // console.error(`Error parsing embedding for relation_id ${row.relation_id}:`, e);
                    eventEmbedding = null;
                }

                return {
                    relation_id: row.relation_id,
                    eventsorting_embedding: eventEmbedding
                };
            }).filter(item => item.eventsorting_embedding !== null); // 過濾掉解析失敗的

        } catch (err) {
            // 這裡不中斷流程，如果查詢失敗，則進入創建新 ID 流程
            console.error('middlewares-insertNews(): database search error ( Eventsorting Embeddings )', err);
        }

        // 2. 進行相似度判斷
        // 假設 findNewsRelationId (您引入的函式) 已經被更正為使用 Eventsorting Embedding 邏輯
        const matchedRelationId = findNewsRelationId(embedding, allEventsortingEmbeddings, SIMILARITY_THRESHOLD);

        if (matchedRelationId !== null) {
            // A. 找到匹配，使用現有的 ID (Eventsorting ID 即為 Relation ID)
            relation_id = matchedRelationId;
            //console.log(`[Relation Match] 覆蓋 relation_id 為: ${matchedRelationId} (相似度 > ${SIMILARITY_THRESHOLD})`);

        } else {
            // B. 未找到匹配，創建新的 Relation ID 並同步 Eventsorting Data

            // i. 創建 Relation ID (插入 relation_data)
            try {
                let fakeReq = {
                    body: { keyword: keyword } // 沿用原本通過 keyword 創建 relation 的方式
                };
                let insertRelationResult = await callAndCatchApiSuccess( insertRelation, fakeReq );

                if (!insertRelationResult?.insertId) {
                     throw new Error("insertRelation did not return a valid insertId");
                }

                relation_id = insertRelationResult.insertId;
                //console.log(`[Relation Creation] 創建新的 relation_id: ${relation_id}`);

                // ii. 創建 Event Sorting Data (同步插入 eventsorting_data)
                // 這裡假設 eventsorting_id = relation_id
                let eventSql = `
                    INSERT IGNORE INTO eventsorting_data ( eventsorting_id, eventsorting_embedding )
                    VALUE ( ?, ? )
                `;
                let eventParams = [
                    relation_id,
                    embeddingJson,
                ];

                await pool.query(eventSql, eventParams);

            } catch (err) {
                // 如果失敗，則刪除可能已創建的 image 和 relation_data
                await callDeleteNews( null, image_id, relation_id );
                err.desc = 'middlewares-insertNews(): database insert error ( relation / eventsorting )';
                return next(err);
            }
        }

        // 最終檢查
        if ( !relation_id ) {
            let err = new Error("relation_id cannot be null");
            err.desc = "middlewares-insertNews(): relation_id is null after all checks and fallbacks";
            return next(err);
        }

        // -----------------------------------------------------

        // 插入資料庫
        let sql = '', params = []

        // 1. 插入 news_data
        sql = `
            INSERT INTO news_data (
                origin_url,
                channel_id,
                relation_id,
                cover_image,
                news_title,
                news_date,
                news_embedding
            ) VALUES (?, ?, ?, ?, ?, ?, ?);
        `;
        params = [ url, channel_id, relation_id, cover_img_id, title, publish_date, embeddingJson ];

        try {
            const [newsDataResult] = await pool.query(sql, params);
            news_id = newsDataResult.insertId;
        } catch (err) {
            await callDeleteNews( null, image_id, relation_id );
            err.desc = 'middlewares-insertNews(): database insert error ( data )';
            return next(err)
        }

        // 【此處移除原有的 Eventsorting UPDATE 邏輯，因為在創建時已同步完成】


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
        let bodyValuesSql = [];

        if (detail && Array.isArray(detail)) {
            for( let item of detail ) {

                let type = null;
                let text = null;
                let img_id = null;

                if ( typeof item === 'string' ) {
                    type = 'text';
                    text = item;

                } else if ( typeof item === 'object' && (item.text || item.img?.src) ) {
                    // 根據您提供的資料結構 (text/img object) 進行解析
                    text = item.text || null;
                    if (item.img?.src) {
                        type = 'image';
                        try {
                            // 呼叫 getImgId 處理圖片內容
                            img_id = await getImgId( item.img );
                            image_id.push( img_id );
                        } catch (err) {
                            await callDeleteNews( news_id, image_id, null );
                            err.desc = 'middlewares-insertNews(): database insert error ( body - img )';
                            return next(err);
                        }
                    } else if (text) {
                        type = 'text';
                    }
                } else if (typeof item === 'object' && item.src) {
                     // 處理直接是圖片物件的情況
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

                if (type) {
                    bodyValuesSql.push( `( ?, ?, ?, ?, ?)` );
                    params.push(news_id, type, text, img_id, order);
                    order += 10;
                }
            }
        }

        // 只有當有 body 內容時才執行 news_body 插入
        if (bodyValuesSql.length > 0) {
            let finalSql = sql + bodyValuesSql.join(', ');
            try {
                let [newsBodyResult] = await pool.query(finalSql, params);
            } catch (err) {
                // news_body 插入失敗，刪除已創建的 news 和所有關聯
                await callDeleteNews( news_id, null, null );
                err.desc = 'middlewares-insertNews(): database insert error ( body )';
                return next(err);
            }
        }


        // 3. 插入 news_group
        /*group = !group? [null]: group;
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
                // 不影響主流程，只記錄警告
                console.warn('[Search Group Failed]', err.message);
            }

            // 插入 news_group
            if ( group_type != null && group_id != null ) {
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
                    // 這裡只警告，不中斷主流程
                    console.warn('middlewares-insertNews(): database insert error ( group )', err.message);
                }
            }
        }*/

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
                    if ( location_type != null && location_id != null ) {
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
                            // 這裡只警告，不中斷主流程
                            console.warn('middlewares-insertNews(): database insert error ( location )', err.message);
                        }
                    }
                }
            }
        }

        // 5. 插入 news_keyword
        /*if (keyword && keyword.length > 0) {
            let keyword_ids = [];
            // 先將所有關鍵字插入 keyword_data 表，並取得其 ID
            for (let each_keyword of keyword) {
                if (each_keyword) {
                    try {
                        // 假設 insertKeyword 接受 keyword name 並返回 { insertId: keyword_id }
                        fakeReq = {
                            body: { name: each_keyword }
                        };
                        // 確保 insertKeyword 函式已被引入
                        let insertKeywordResult = await callAndCatchApiSuccess( insertKeyword, fakeReq );
                        if (insertKeywordResult?.insertId) {
                            keyword_ids.push(insertKeywordResult.insertId);
                        }
                    } catch (err) {
                        // 警告並繼續下一個關鍵字，不中斷主流程
                        console.warn('[Insert Keyword Failed]', err.message);
                    }
                }
            }

            // 批量插入 news_keyword 橋接表
            if (keyword_ids.length > 0) {
                let keywordValuesSql = keyword_ids.map(() => `( ?, ? )`).join(', ');
                let keywordParams = keyword_ids.flatMap(id => [relation, id]);

                sql = `
                    INSERT INTO relation_keyword (
                        relation,
                        keyword_id
                    ) VALUES ${keywordValuesSql}
                `;
                try {
                    await pool.query(sql, keywordParams);
                } catch (err) {
                    // 這裡只警告，不中斷主流程
                    console.warn('middlewares-insertNews(): database insert error ( news_keyword )', err.message);
                }
            }
        }*/

        // 6. 插入 news_comment
        /*if (comment && Array.isArray(comment) && comment.length > 0) {

            // 由於 comment 陣列可能包含空字串或無效值，先過濾
            const validComments = comment.filter(cmt => cmt && typeof cmt === 'string' && cmt.trim().length > 0);

            if (validComments.length > 0) {
                let commentValuesSql = validComments.map(() => `( ?, ? )`).join(', ');
                // 參數格式: [news_id, comment_text_1, news_id, comment_text_2, ...]
                let commentParams = validComments.flatMap(cmt => [news_id, cmt]);

                sql = `
                    INSERT INTO news_comment (
                        news_id,
                        comment_text
                    ) VALUES ${commentValuesSql}
                `;
                try {
                    await pool.query(sql, commentParams);
                } catch (err) {
                    // 這裡只警告，不中斷主流程
                    console.warn('middlewares-insertNews(): database insert error ( news_comment )', err.message);
                }
            }
        }*/

        // 最終回傳
        return res.apiSuccess({insertId: news_id, relation_id: relation_id}, "Insert Success");
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