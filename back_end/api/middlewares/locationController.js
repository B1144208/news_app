const pool = require('../connect_db');
const { checkRequireField } = require('../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');
const { locationSearch } = require('../utils/stringHelper');

// search
async function searchLocation (req, res, next) {

    let {name, type} = req.query?? {}

    // 檢查必要欄位 & 格式
    try {
        [ name, type ] = await checkRequireField ([
            { field: 'name' , data: name , type: 'string' },
            { field: 'type' , data: type , type: 'string', enum: ["regions", "countries", "states"] }
        ], "middlewares-searchLocation()");
    } catch (err) {
        return next(err)
    }
    
    // general search
    if ( !name && !type ) {
        let sql = `
            SELECT * 
            FROM location_regions
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