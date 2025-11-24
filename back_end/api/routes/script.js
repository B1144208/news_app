const express = require('express')
const router = express.Router()
const { generalScript, reporterScript, reporterScriptFast, chatScript, quickScript, callAskScript } = require('../middlewares/scriptController')

// general mode
router.get('/general/:id', generalScript);

// reporter mode
router.get('/reporter_fast/:id', reporterScriptFast);
router.get('/reporter/:id', reporterScript);

// chat mode
router.get('/chat/:id', chatScript);

// quick mode
router.get('/quick', quickScript);

router.post("/ask", callAskScript);

module.exports = router