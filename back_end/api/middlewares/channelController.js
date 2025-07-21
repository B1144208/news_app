const pool = require('../connect_db')
const { callAndCatchApiSuccess } = require('../utils/fakeHelper')
const { insertImage, deleteImage } = require('./imageController')

// search
async function searchChannel(req, res, next) {
    const name = req.query.name;

    let sql = `
        SELECT * 
        FROM channel_data 
        WHERE 1
    `;
    let params = [];

    // general search
    if (!name) {
        try {
            let [result] = await pool.query(sql, params);
            return res.apiSuccess(result, 'Search Success');
        } catch (err) {
            err.desc = 'middlewares-searchChannel(): database search error';
            return next(err);
        }
    }

    // name search
    try {
        
        sql = `
            SELECT * 
            FROM channel_data
            WHERE channel_name LIKE ?
        `;
        params = [`%${name}%`];
        let [result] = await pool.query(sql, params);

        if (result.length > 0) {
            return res.apiSuccess({
                searchId: result[0].channel_id
            }, 'Search Success');
        }

        // No results found
        const err = new Error('Not Found Channel');
        err.status = 404;
        err.desc = 'middlewares-searchChannel(): database search error (name search - not found channel)';
        throw err;
        
        //return res.apiError(new Error('Not Found Channel'), 404);

    } catch (err) {
        err.desc = 'middlewares-searchChannel(): database search error (name search)';
        return next(err);
    }
}

// insert
async function insertChannel(req, res, next) {
    let { url, img, name, type, update_rate, introduce } = req.body;

    // Check for required field
    if (!name) {
        let err = new Error('Internal Server Error');
        err.desc = 'middlewares-insertChannel(): Missing required fields - name';
        err.status = 400;
        return next(err);
    }

    // Sanitize input
    url = (!url || url.trim() === '') ? null : url;
    img = (!img || img.trim() === '') ? null : img;
    type = (!type || type.trim() === '') ? null : type;
    update_rate = (!update_rate || update_rate.trim() === '') ? null : update_rate;
    introduce = (!introduce || introduce.trim() === '') ? null : introduce;

    // Insert image if provided
    let img_id = null
    if (img) {
        try {
            let fakeReq = {
                body: {
                    img: img
                }
            }
            const result = await callAndCatchApiSuccess( insertImage, fakeReq );
            img_id = result.insertId;
        } catch (err) {
            console.warn('[Insert Image Failed]', err.message);
        }
    }

    const sql = `
        INSERT INTO channel_data (
            channel_url, 
            image_id, 
            channel_name, 
            channel_type, 
            channel_update, 
            channel_introduction
        ) VALUES (?, ?, ?, ?, ?, ?)
    `;
    const params = [url, img_id, name, type, update_rate, introduce];

    try {
        const [result] = await pool.query(sql, params);
        return res.apiSuccess({ insertId: result.insertId }, 'Insert Success');
    } catch (err) {
        err.desc = 'middlewares-insertChannel(): database insert error';

        // Try to clean up inserted image if insertion failed
        if ( img_id ) {
            try {
                let fakeReq = {
                    params: {
                        id: img_id
                    }
                }
                await callAndCatchApiSuccess( deleteImage, fakeReq );
            } catch (deleteErr) {
                deleteErr.desc = err.desc + ' & image delete error';
                return next(deleteErr);
            }
        }

        return next(err);
    }
}

// update
async function updateChannel(req, res, next) {
    return;
}

// delete
async function deleteChannel(req, res, next) {
    const { type, id } = req.params;
    return;
}

module.exports = {
    searchChannel,
    insertChannel,
    updateChannel,
    deleteChannel
};