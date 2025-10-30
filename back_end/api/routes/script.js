const express = require('express')
const router = express.Router()
const { generalScript, reporterScript, chatScript, quickScript, callAskScript } = require('../middlewares/scriptController')

// general mode
router.post('/general', generalScript);

// reporter mode
router.post('/reporter', reporterScript);

// chat mode
router.post('/chat', chatScript);

// quick mode
router.post('/quick', quickScript);

router.post("/ask", callAskScript);

module.exports = router