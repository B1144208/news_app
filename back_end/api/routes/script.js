const express = require('express')
const router = express.Router()
const { generalScript, reporterScript, chatScript, quickScript } = require('../middlewares/scriptController')

import { callAskScript } from "../middlewares/scriptController.js";



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
router.post('/', generalScript);

// reporter mode
router.post('/', reporterScript);

// chat mode
router.post('/', chatScript);

// quick mode
router.post('/', quickScript);

module.exports = router