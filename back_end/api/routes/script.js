const express = require('express')
const router = express.Router()
const { generalScript, reporterScript, chatScript, quickScript } = require('../middlewares/scriptController')


// general mode
router.post('/', generalScript);

// reporter mode
router.post('/', reporterScript);

// chat mode
router.post('/', chatScript);

// quick mode
router.post('/', quickScript);

module.exports = router