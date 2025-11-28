//const fetch = require('node-fetch');

const OLLAMA_URL = 'http://localhost:11434';

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
 * 根據新聞 embedding 判斷最匹配的 relation_id。
 * @param {number[]} newsEmbedding - 新聞的 embedding 向量。
 * @param {Array<{relation_id: string|number, eventsorting_embedding: number[]}>} relations -
 * 可能的 relation 列表。每個 relation 應包含一個 ID 和它連結到的 eventsorting embedding。
 * @param {number} threshold - 判斷相似度的門檻值 (預設為 0.9)。
 * @returns {string|number|null} 匹配的 relation_id，如果沒有找到則返回 null。
 */
function findRelationId(newsEmbedding, relations, threshold = 0.9) {
    if (!newsEmbedding || newsEmbedding.length === 0) {
        console.warn('News embedding is invalid.');
        return null;
    }

    let bestMatchId = null;
    let maxSimilarity = -1;

    for (const relation of relations) {
        const eventEmbedding = relation.eventsorting_embedding;
        if (eventEmbedding && eventEmbedding.length > 0) {

            const similarity = calculateSimilarity(newsEmbedding, eventEmbedding);

            // 檢查是否超過門檻值
            if (similarity > threshold) {
                // 如果有多個 relation 都超過門檻，則選取相似度最高的
                if (similarity > maxSimilarity) {
                    maxSimilarity = similarity;
                    bestMatchId = relation.relation_id;
                }
            }
        }
    }

    return bestMatchId;
}

module.exports = {
    getEmbedding
    calculateSimilarity,
    findRelationId
};
