const express = require('express')
const router = express.Router()
const { getText, getScript, getQuickScipt,  callAskScript } = require('../middlewares/scriptController')

// general mode
router.get('/text', getText);
router.get('/general', getScript);
router.get('/quick', getQuickScipt);

// reporter mode
//router.get('/reporter_fast', reporterScriptFast);

router.post("/ask", callAskScript);

module.exports = router