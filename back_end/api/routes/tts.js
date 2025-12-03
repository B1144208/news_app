const express = require('express');
const router = express.Router();

// 引入 TTS controller
const { textToSpeech, getVoices, saveQuickPlay } = require('../middlewares/ttsController');

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

/*
 * POST /api/tts/save-quickplay
 * 快速播放專用：文字轉語音並儲存到 public/audio/quickplay/
 * Body: { text: string, filename: string, voiceId?: string }
 */
router.post('/save-quickplay', saveQuickPlay);

module.exports = router;