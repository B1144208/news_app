const pool = require('../connect_db');
const { checkRequireField } = require('../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');
const { locationSearch } = require('../utils/stringHelper');

// search
async function searchLocation (req, res, next) {

    let {name, type, aggregationId, aggregationType} = req.query?? {} // 💡 1. 於 query 參數新增聚合參數

    // 檢查必要欄位 & 格式
    try {
        [ name, type, aggregationId, aggregationType ] = await checkRequireField ([
            { field: 'name' , data: name , type: 'string' },
            { field: 'type' , data: type , type: 'string', enum: ["regions", "countries", "states"] },
            { field: 'aggregationId' , data: aggregationId , type: 'number' },
            { field: 'aggregationType' , data: aggregationType , type: 'string', enum: ["region", "country"] }
        ], "middlewares-searchLocation()");
    } catch (err) {
        return next(err)
    }

    // 💡 2. 新增 location aggregation search 模式
    // 讓前端可以透過 /location?aggregationId=...&aggregationType=... 來取得所有相關 ID 列表
    if ( aggregationId && aggregationType ) {
        let sql = `
            SELECT
                LR.region_id,
                LC.country_id,
                LS.state_id
            FROM location_regions AS LR
            NATURAL JOIN location_countries AS LC
            NATURAL JOIN location_states AS LS
            WHERE 1
        `;
        let params = [];

        // 根據 aggregationType 篩選，選出所有相關 R-C-S 組合
        if (aggregationType === 'region') {
            sql += ` AND LR.region_id = ? `;
            params.push(aggregationId);
        } else if (aggregationType === 'country') {
            sql += ` AND LC.country_id = ? `;
            params.push(aggregationId);
        } else {
            return res.apiSuccess([], "Aggregation Success (Unsupported Type)")
        }

        try {
            let [result] = await pool.query(sql, params);

            // 使用 Set 確保 ID 不重複
            let aggregatedIds = new Set();

            result.forEach(row => {
                // 將所有相關的 ID 納入集合，Set 會自動去重
                if (row.region_id) aggregatedIds.add(row.region_id);
                if (row.country_id) aggregatedIds.add(row.country_id);
                if (row.state_id) aggregatedIds.add(row.state_id);
            });

            // 回傳所有相關的 ID 列表 (例如 [1, 10, 101, 102, ...])
            return res.apiSuccess(Array.from(aggregatedIds), "Aggregation Success");

        } catch (err){
            err.desc = 'middlewares-searchLocation(): database search error (aggregation search)'
            return next(err)
        }
    }

    // general search
    if ( !name && !type ) {
        let sql = `
            SELECT * FROM location_regions
            NATURAL JOIN location_countries
            NATURAL JOIN location_states
            WHERE 1
        `;
        let params = [];
        try {
            let [result] = await pool.query(sql, params);
            return res.apiSuccess(result, "Search Success")
        } catch (err){
            err.desc = 'middlewares-searchLocation(): database search error (general search)'
            return next(err)
        }
    }

    // type search
    if ( type ) {
        let sql = `
            SELECT *
            FROM location_${type}
            WHERE 1
        `;
        let params = [];
        if (!name) {
            try {
                let [result] = await pool.query( sql, params );
                return res.apiSuccess(result, "Search Success");
            } catch (err) {
                err.desc = "middlewares-searchLocation(): database search error";
                return next(err);
            }
        }
        try {
            let {sql, params} = locationSearch ('location_'+type, type+'_name', name);
            let [result] = await pool.query(sql, params);
            return res.apiSuccess(result, "Search Success");
        } catch (err) {
            err.desc = "middlewares-searchLocation(): database search error";
            return next(err);
        }
    }
    

    // name search
    // 儲存匹配的結果
    let highestMatch = {
        region_list: [],
        country_list: [],
        state_list: []
    };
    // 先查 location_regions
    try {
        let {sql, params} = locationSearch ('location_regions', 'region_name', name);
        let [regionResult] = await pool.query(sql, params);
        if ( regionResult.length > 0 ) {
            regionResult.forEach ( region => {
                highestMatch.region_list.push( region.region_id );
            })
        }
    } catch (err){
        err.desc = 'middlewares-searchLocation(): database search error (name search-region)'
        console.log (err);
    }
    // 再查 group_countries ( UNIQUE in name )
    try {
        let { sql, params } = locationSearch ('location_countries', 'country_name', name);
        let [countryResult] = await pool.query(sql, params);
        if ( countryResult.length > 0 ) {
            countryResult.forEach ( country => {
                highestMatch.country_list.push( country.country_id );
            })
        }   
    } catch (err){
        err.desc = 'middlewares-searchLocation(): database search error (name search-country)'
        console.log (err);
    }

    // 最後查 location_states ( NOT UNIQUE in name )
    try {
        let { sql, params } = locationSearch ('location_states', 'state_name', name);
        let [stateResult] = await pool.query(sql, params);
        if ( stateResult.length > 0 ) {
            stateResult.forEach ( state => {
                highestMatch.state_list.push( state.state_id );
            })
        }
    } catch (err){
        err.desc = 'middlewares-searchLocation(): database search error (name search-state)'
        console.log (err);
        //return next(err)
    }

    // 回傳資料
    if ( ( highestMatch.region_list.length + highestMatch.country_list.length + highestMatch.state_list.length ) === 0 ) {
        return res.apiSuccess ( { type: null, id: null}, 'Search Success' );
    } else if ( highestMatch.state_list.length === 1 ) {
        return res.apiSuccess ( { type: 'state', id: highestMatch.state_list[0]}, 'Search Success' );
    } else if ( highestMatch.country_list.length === 1 ) {
        return res.apiSuccess ( { type: 'country', id: highestMatch.country_list[0]}, 'Search Success' );
    } else if ( highestMatch.region_list.length === 1 ) {
        return res.apiSuccess ( { type: 'region', id: highestMatch.region_list[0]}, 'Search Success' );
    } else {
        return res.apiSuccess ( { type: null, id: null}, 'Search Success' );
    }
}

// insert
async function insertLocation (req, res, next) {
    return;
}

// update
async function updateLocation(req, res, next) {
    return;
}

// delete
async function deleteLocation(req, res, next) {
    const id = req.params?.id;
    return;
}

module.exports = {
    searchLocation,
    insertLocation,
    updateLocation,
    deleteLocation
}