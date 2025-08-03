const express = require('express')
const router = express.Router()
const { searchKeyword, insertKeyword, updateKeyword, deleteKeyword } = require('../middlewares/keywordController');

// search
router.get('/', searchKeyword);

// insert
router.post('/', insertKeyword);

// update
router.put('/', async (req, res, next) => {
    res.send('This is the update route');
});

// delete
router.delete('/', deleteKeyword);
router.delete('/:id', deleteKeyword);

module.exports = router