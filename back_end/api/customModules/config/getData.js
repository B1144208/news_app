const pool = require('../../connect_db');
const { checkRequireField } = require('../../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../../utils/fakeHelper');
const path = require('path');
const fs = require('fs').promises;

async function getGroup (req, res, next) {
    try {
        let sql = `
            SELECT 
                group_id AS data_id,
                group_name AS name
            FROM group_data 
            ORDER BY data_id
        `;
        
        let [groupDataResult] = await pool.query(sql);

        sql = `
            SELECT 
                group_detail_id AS detail_id,
                group_id AS data_id,
                group_detail_name AS name
            FROM group_detail
            ORDER BY detail_id;
        `;
        let [groupDetailResult] = await pool.query(sql);

        const data = {
            group_data: groupDataResult,
            group_detail: groupDetailResult
        };

        const filePath = path.join(__dirname, 'group.json');
        await fs.writeFile(filePath, JSON.stringify(data, null, 2), 'utf8');

        return res.apiSuccess({});
    } catch (err) {
        err.desc = "customModules-getGroup: database search error";
        return next(err);
    }
    
}

async function getLocation (req, res, next) {

    try {
        let sql = `
            SELECT
                region_id,
                region_name_en AS name_en,
                region_name_zh_tw AS name_zh
            FROM location_regions 
            ORDER BY region_id
        `;
        
        let [locationRegionResult] = await pool.query(sql);

        sql = `
            SELECT
                country_id,
                region_id,
                country_name_en AS name_en,
                country_name_zh_tw AS name_zh
            FROM location_countries
            ORDER BY country_id;
        `;
        let [locationCountryResult] = await pool.query(sql);
        sql = `
            SELECT
                state_id,
                country_id,
                state_name_en AS name_en,
                state_name_zh_tw AS name_zh
            FROM location_states
            ORDER BY state_id;
        `;
        let [locationStateResult] = await pool.query(sql);

        const data = {
            location_region: locationRegionResult,
            location_country: locationCountryResult,
            location_state: locationStateResult
        };

        const filePath = path.join(__dirname, 'location.json');
        await fs.writeFile(filePath, JSON.stringify(data, null, 2), 'utf8');

        return res.apiSuccess({});
    } catch (err) {
        err.desc = "customModules-getGroup: database search error";
        return next(err);
    }
}

module.exports = {
    getGroup,
    getLocation
}