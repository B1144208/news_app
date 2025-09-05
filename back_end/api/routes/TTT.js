const express = require('express')
const router = express.Router()
const { searchTTT, insertTTT, updateTTT, deleteTTT } = require('../middlewares/TTTController')

// search
router.get('/', async (req, res, next) => {
    res.send('This is the search route');
});

// insert
router.post('/', async (req, res, next) => {
    res.send('This is the insert route');
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