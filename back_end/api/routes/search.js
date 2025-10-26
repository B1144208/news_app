const express = require('express')
const router = express.Router()
const { historyRecord, popularSearch, generalSearch } = require('../middlewares/searchController');
const { getClientIp } = require('../utils/clientHelper');


// general search
router.get('/', getClientIp, generalSearch);

// other search
router.get('/history/:userId', historyRecord);
router.get('/popular', popularSearch);


module.exports = router