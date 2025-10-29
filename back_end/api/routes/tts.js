const express = require('express');
const router = express.Router();

// 引入 TTS controller
const { textToSpeech, getVoices } = require('../middlewares/ttsController');

/**
 * POST /api/tts
 * 文字轉語音（串流音訊）
 * Body: { text: string, voiceId?: string, stability?: number, similarity_boost?: number }
 */
router.post('/', textToSpeech);

/**
 * GET /api/tts/voices
 * 獲取可用的語音列表
 */
router.get('/voices', getVoices);

module.exports = router;