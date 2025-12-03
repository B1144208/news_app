const express = require('express')
const router = express.Router()
const { getText, getScript, reporterMake, chatMake,  callAskScript } = require('../middlewares/scriptController')

// general mode
router.get('/text', getText);
router.get('/get', getScript);

// reporter mode
//router.get('/reporter_fast', reporterScriptFast);

router.post("/ask", callAskScript);

module.exports = router