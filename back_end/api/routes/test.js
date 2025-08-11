const express = require('express')
const router = express.Router()
const { testCheckRequireField } = require('../middlewares/testController')

// checkRequireField
router.get('/crf', testCheckRequireField );



module.exports = router