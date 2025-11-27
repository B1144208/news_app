const fetch = require('node-fetch');

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

module.exports = {
    getEmbedding
};
