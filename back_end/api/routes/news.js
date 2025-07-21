const express = require('express')
const router = express.Router()
const pool = require('../connect_db')
const { searchNews, insertNews, updateNews, deleteNews } = require('../middlewares/newsController');


// search
router.get('/', searchNews);

// insert
router.post('/', insertNews);

// update
router.put('/', async (req, res, next) => {
    res.send('This is the update route');
});

// delete
router.delete('/', deleteNews);

module.exports = router