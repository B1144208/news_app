const express = require('express')
const router = express.Router()
const { generalScript, reporterScript, chatScript, quickScript, callAskScript } = require('../middlewares/scriptController')

// general mode
router.get('/general/:id', generalScript);

// reporter mode
router.get('/reporter/:id', reporterScript);

// chat mode
router.get('/chat/:id', chatScript);

// quick mode
router.get('/quick', quickScript);

router.post("/ask", callAskScript);

module.exports = router