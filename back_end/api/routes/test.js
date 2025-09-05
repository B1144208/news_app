const express = require('express')
const router = express.Router()
const { testCheckRequireField } = require('../middlewares/testController')
const { getClientInfo, getClientIp } = require('../utils/clientHelper');

// checkRequireField
router.get('/crf', testCheckRequireField );

// getClintInfo
router.get('/info', getClientInfo);
router.get('/ip', getClientIp);


module.exports = router