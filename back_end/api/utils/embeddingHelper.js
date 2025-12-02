// embeddingHelper.js

//const fetch = require('node-fetch');

const OLLAMA_URL = 'http://localhost:11434';
const pool = require('../connect_db');

/**
 * 計算兩個向量之間的餘弦相似度 (Cosine Similarity)。
 * @param {number[]} vectorA - 第一個 embedding 向量。
 * @param {number[]} vectorB - 第二個 embedding 向量。
 * @returns {number} 相似度值 (0 到 1 之間)。
 */
function calculateSimilarity(vectorA, vectorB) {
    if (!vectorA || !vectorB || vectorA.length !== vectorB.length || vectorA.length === 0) {
        return 0;
    }

    let dotProduct = 0;
    let magnitudeA = 0;
    let magnitudeB = 0;

    for (let i = 0; i < vectorA.length; i++) {
        dotProduct += vectorA[i] * vectorB[i];
        magnitudeA += vectorA[i] * vectorA[i];
        magnitudeB += vectorB[i] * vectorB[i];
    }

    magnitudeA = Math.sqrt(magnitudeA);
    magnitudeB = Math.sqrt(magnitudeB);

    if (magnitudeA === 0 || magnitudeB === 0) {
        return 0;
    }

    return dotProduct / (magnitudeA * magnitudeB);
}

/**
 * [News Relation 判斷]
 * 根據新的新聞 Embedding，與現有 *Eventsorting* 資料表中的 Embedding 進行相似度比較。
 * @param {number[]} newNewsEmbedding - 新聞標題/內容的 Embedding 向量。
 * @param {Array<{relation_id: number, eventsorting_embedding: number[]}>} existingEvents - 現有的 EventSorting 列表。
 * @param {number} threshold - 相似度門檻值 (預設 0.85)。
 * @returns {number|null} 找到的 bestMatchId (即 eventsorting_id) 或 null。
 */
function findNewsRelationId(newNewsEmbedding, existingEvents, threshold = 0.85) {
    let maxSimilarity = -1;
    let bestMatchId = null;

    if (!newNewsEmbedding || newNewsEmbedding.length === 0) return null;

    for (const event of existingEvents) {
        let existingEmbedding = event.eventsorting_embedding; // ⭐ 參考 eventsorting_embedding ⭐
        const relationId = event.relation_id; // 假設這裡的 relation_id 是 eventsorting_id

        if (existingEmbedding && existingEmbedding.length > 0 && relationId !== null) {
            const similarity = calculateSimilarity(newNewsEmbedding, existingEmbedding);

            if (similarity > threshold) {
                if (similarity > maxSimilarity) {
                    maxSimilarity = similarity;
                    bestMatchId = relationId;
                }
            }
        }
    }

    return bestMatchId;
}

/**
 * [Keyword Relation 判斷]
 * 根據新的 Keyword embedding 判斷最匹配的 keyword_relation_id。
 * @param {number[]} newKeywordEmbedding - 新的 Keyword 的 embedding 向量。
 * @param {Array<{keyword_relation_id: string|number, keyword_embedding: number[]}>} existingKeywords -
 * 現有 Keyword 列表。每個應包含一個 keyword_relation_id 和 keyword_embedding。
 * @param {number} threshold - 判斷相似度的門檻值 (預設為 0.9)。
 * @returns {string|number|null} 匹配的 keyword_relation_id，如果沒有找到則返回 null。
 */
function findKeywordRelationId(newKeywordEmbedding, existingKeywords, threshold = 0.85) {
    if (!newKeywordEmbedding || newKeywordEmbedding.length === 0) {
        console.warn('New keyword embedding is invalid.');
        return null;
    }

    let bestMatchId = null;
    let maxSimilarity = -1;

    for (const keyword of existingKeywords) {
        const existingEmbedding = keyword.keyword_embedding;
        const relationId = keyword.keyword_relation_id;

        // 確保有有效的 embedding 和 relation ID
        if (existingEmbedding && existingEmbedding.length > 0 && relationId !== null) {

            const similarity = calculateSimilarity(newKeywordEmbedding, existingEmbedding);

            // 檢查是否超過門檻值
            if (similarity > threshold) {
                // 如果有多個都超過門檻，則選取相似度最高的
                if (similarity > maxSimilarity) {
                    maxSimilarity = similarity;
                    bestMatchId = relationId;
                }
            }
        }
    }

    return bestMatchId;
}

/**
 * [Events Sorting 判斷]
 * 根據新事件的 Embedding 尋找資料庫中相似度高的舊事件（用於 Horizontal 連結）。
 * @param {number[]} newEmbedding - 待搜尋事件的 embedding 向量。
 * @param {number} currentEventId - 當前事件 ID (用於排除自己)。
 * @param {number} threshold - 相似度門檻值 (e.g., 0.75)。
 * @returns {Promise<number[]>} 相似事件的 eventsorting_id 陣列。
 */
async function findSimilarEvents(newEmbedding, currentEventId, threshold = 0.8) {
    // 查詢所有現有事件的 ID 和 Embedding
    const sql = `
        SELECT eventsorting_id, eventsorting_embedding -- <<< 修正：欄位名稱從 embedding_json 改為 eventsorting_embedding
        FROM eventsorting_data
        WHERE eventsorting_id != ?
        AND eventsorting_embedding IS NOT NULL          -- <<< 修正
        AND CHAR_LENGTH(eventsorting_embedding) > 10    -- <<< 修正 (確保不是空 JSON [])
    `;

    const [existingEvents] = await pool.query(sql, [currentEventId]); // 使用 pool

    let relatedIds = [];

    for (const event of existingEvents) {
        try {
            // <<< 修正：使用正確的欄位名稱 eventsorting_embedding 進行解析
            const existingEmbedding = JSON.parse(event.eventsorting_embedding);

            const similarity = calculateSimilarity(newEmbedding, existingEmbedding);

            if (similarity >= threshold) {
                relatedIds.push({
                    related_eventsorting_id: event.eventsorting_id,
                    similarity: similarity
                });
            }
        } catch (e) {
            // 忽略無效的 Embedding 資料，但記錄一下
            console.warn(`[EmbeddingHelper] 無法解析事件 ID ${event.eventsorting_id} 的 Embedding 資料:`, e.message);
        }
    }

    relatedIds.sort((a, b) => b.similarity - a.similarity);

    // 返回前 10 個最相關的事件 ID
    return relatedIds.slice(0, 10).map(r => r.related_eventsorting_id);
}

async function getEmbedding(text) {

    const cleaned = (text || '').replace(/\s+/g, ' ').trim();
    if (!cleaned) return null;

    const res = await fetch(`${OLLAMA_URL}/api/embeddings`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
        model: 'nomic-embed-text',
        prompt: cleaned
        })
    });

    if (!res.ok) {
        const text = await res.text();
        console.error('Ollama embedding error:', res.status, text);
        throw new Error('Failed to get embedding from Ollama');
    }

    const data = await res.json();
    // data.embedding 是一個 number[]
    return data.embedding;
}

module.exports = {
    getEmbedding,
    calculateSimilarity,
    findNewsRelationId,
    findKeywordRelationId,
    findSimilarEvents
};