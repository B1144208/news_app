// ========== 使用 Node.js 內建 fetch (Node.js >= 18) ==========
// 如果此版本仍有問題，請使用 ttsController-node-fetch.js

const { checkRequireField } = require('../utils/checkHelper');

// ElevenLabs API 配置
const ELEVENLABS_API_KEY = process.env.ELEVENLABS_API_KEY;
const DEFAULT_VOICE_ID = "21m00Tcm4TlvDq8ikWAM"; // Rachel - 預設英文語音
const STACY = "hkfHEbBvdQFNX4uWHqRF"; //Standard Chinese, narrative & story
const YU = "fQj4gJSexpu8RDE2Ii5m"; //Taiwan, conversational
const KEVIN_TU = "BrbEfHMQu0fyclQR7lfh"; //Taiwan, narrative & story
const ANNA_SU = "9lHjugDhwqoxA5MhX0az"; //Taiwan, social media
const API_BASE_URL = "https://api.elevenlabs.io/v1";

/**
 * 文字轉語音 API
 * 直接串流音訊到前端，不儲存檔案
 */
async function textToSpeech(req, res, next) {
    try {
        // 驗證 API Key
        if (!ELEVENLABS_API_KEY) {
            const error = new Error('ELEVENLABS_API_KEY 未設定');
            error.status = 500;
            error.desc = "TTS-textToSpeech(): Missing API Key in environment variables";
            return next(error);
        }

        // 取得參數
        let {
            text,
            voiceId = DEFAULT_VOICE_ID,
            stability = 0.5,
            similarity_boost = 0.75,
            model_id = "eleven_multilingual_v2"
        } = req.body;

        // 檢查必要欄位
        try {
            [text] = await checkRequireField([
                { field: 'text', data: text, type: 'string', other: ['required'] }
            ]);
        } catch (err) {
            err.desc = "TTS-textToSpeech(): Missing required field 'text'";
            return next(err);
        }

        // 驗證文字長度（ElevenLabs 限制 5000 字元）
        if (text.length > 5000) {
            const error = new Error('文字長度超過 5000 字元限制');
            error.status = 400;
            error.desc = "TTS-textToSpeech(): Text length exceeds 5000 characters";
            return next(error);
        }

        // 準備請求
        const url = `${API_BASE_URL}/text-to-speech/${voiceId}`;
        const payload = {
            text,
            model_id,
            voice_settings: {
                stability: parseFloat(stability),
                similarity_boost: parseFloat(similarity_boost)
            }
        };

        console.log(`[TTS] 生成語音 - 文字長度: ${text.length}, Voice: ${voiceId}`);

        // 呼叫 ElevenLabs API（使用內建 fetch）
        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'xi-api-key': ELEVENLABS_API_KEY,
                'Content-Type': 'application/json',
                'Accept': 'audio/mpeg'
            },
            body: JSON.stringify(payload)
        });

        // 檢查回應
        if (!response.ok) {
            const errorText = await response.text();
            console.error(`[TTS] ElevenLabs API 錯誤: ${response.status} - ${errorText}`);

            const error = new Error(`TTS 服務錯誤: ${response.status}`);
            error.status = response.status;
            error.desc = `TTS-textToSpeech(): ElevenLabs API error - ${errorText}`;
            return next(error);
        }

        // 設定回應標頭並串流音訊
        res.setHeader('Content-Type', 'audio/mpeg');
        res.setHeader('Transfer-Encoding', 'chunked');
        res.setHeader('Cache-Control', 'no-cache');

        // 將音訊串流傳給客戶端（Node.js 18+ 的 ReadableStream）
        const reader = response.body.getReader();

        const pump = async () => {
            try {
                while (true) {
                    const { done, value } = await reader.read();
                    if (done) break;
                    res.write(Buffer.from(value));
                }
                res.end();
                console.log('[TTS] 音訊串流完成');
            } catch (err) {
                console.error('[TTS] 串流錯誤:', err);
                if (!res.headersSent) {
                    next(err);
                }
            }
        };

        pump();

    } catch (error) {
        console.error('[TTS] 發生錯誤:', error);
        error.desc = error.desc || "TTS-textToSpeech(): Unexpected error";
        next(error);
    }
}

/**
 * 獲取可用的語音列表
 */
async function getVoices(req, res, next) {
    try {
        if (!ELEVENLABS_API_KEY) {
            const error = new Error('ELEVENLABS_API_KEY 未設定');
            error.status = 500;
            return next(error);
        }

        const response = await fetch(`${API_BASE_URL}/voices`, {
            method: 'GET',
            headers: {
                'xi-api-key': ELEVENLABS_API_KEY
            }
        });

        if (!response.ok) {
            const errorText = await response.text();
            console.error(`[TTS] 獲取語音列表失敗: ${response.status} - ${errorText}`);

            const error = new Error('無法獲取語音列表');
            error.status = response.status;
            return next(error);
        }

        const data = await response.json();

        // 格式化回應
        const voices = data.voices.map(voice => ({
            voice_id: voice.voice_id,
            name: voice.name,
            category: voice.category,
            labels: voice.labels,
            description: voice.description
        }));

        res.json({
            success: true,
            data: voices,
            count: voices.length
        });

    } catch (error) {
        console.error('[TTS] 獲取語音列表錯誤:', error);
        next(error);
    }
}

module.exports = {
    textToSpeech,
    getVoices
};