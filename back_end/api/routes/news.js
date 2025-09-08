const express = require('express')
const router = express.Router()
const pool = require('../connect_db')
const { searchNews, insertNews, updateNews, deleteNews } = require('../middlewares/newsController');
const { batchNews } = require('../utils/batchHelper');


// search
router.get('/', searchNews);
router.get('/:id', searchNews);

// insert
router.post('/', insertNews);
router.post('/batch', batchNews);

// update
router.put('/', async (req, res, next) => {
    res.send('This is the update route');
});

// delete
router.delete('/', deleteNews);
router.delete('/:id', deleteNews);

module.exports = router