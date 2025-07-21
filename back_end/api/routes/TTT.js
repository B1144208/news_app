const express = require('express')
const router = express.Router()
const pool = require('../connect_db')

// search
router.get('/', async (req, res, next) => {
    let sql = `
        SELECT * 
        FROM TTT 
        NATURAL JOIN TTT
        WHERE 1
    `
    let params = []
    try {
        let [result] = await pool.query(sql, params);
        res.apiSuccess(result, 'Search Success')
    } catch (err){
        err.desc = 'backend-TTT(search) : database search error'
        return next(err)
    }
});

// insert
router.post('/', async (req, res, next) => {

    let { TTT } = req.body;

    // 檢查必要欄位
    if (!TTT) {
        let err = new Error('Internal Server Error')
        err.desc = 'backend-TTT(insert) : Missing required fields - TTT'
        err.status = 400
        return next(err)
    }

    // res.body 處理
    TTT = TTT || null;

    // 插入資料庫
    let sql = `
        INSERT INTO TTT (
            TTT
        ) VALUES (?)
    `;
    let params = [ TTT ]
    try {
        let [result] = await pool.query(sql, params);
        res.apiSuccess({ insertId: result.insertId }, 'Insert Success')
    } catch (err) {
        err.desc = 'backend-TTT(insert) : database insert error'
        return next(err)
    }
});
// update
router.put('/', async (req, res, next) => {
    res.send('This is the update route');
});

// delete
router.delete('/', async (req, res, next) => {
    res.send('This is the delete route');
});


module.exports = router