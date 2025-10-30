const express = require('express')
const router = express.Router()
const { generalScript, reporterScript, chatScript, quickScript, callAskScript } = require('../middlewares/scriptController')




router.post("/ask", async (req, res) => {
  try {
    const { question } = req.body;
    const response = await callAskScript(question);
    res.json({ response });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to execute ask.sh" });
  }
});

// general mode
router.post('/general', generalScript);

// reporter mode
router.post('/reporter', reporterScript);

// chat mode
router.post('/chat', chatScript);

// quick mode
router.post('/quick', quickScript);

module.exports = router