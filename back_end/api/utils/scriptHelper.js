/**
 * 將一整篇新聞內文縮短成不超過 maxChars 字元的摘要：
 * 1. 移除 <think>...</think>
 * 2. 清理多餘空白與換行
 * 3. 以句號/問號/驚嘆號切句
 * 4. 先保留開頭 1～2 句，再優先保留含關鍵資訊的句子，最後補其他句子
 */


function hasFullScript(entry) {
  const hasReporter =
    entry.reporter &&
    entry.reporter.toString().trim().length > 0;
  const hasChat =
    Array.isArray(entry.chat) &&
    entry.chat.length > 0;
  return hasReporter && hasChat;
}

function shortenArticle(text, maxChars = 600) {
  if (!text) return '';

  // 先把 <think>...</think> 整段移掉（如果有的話）
  let raw = text.replace(/<think>[\s\S]*?<\/think>/g, '').trim();

  // 把多餘空白壓縮成一個空格，換行也一起處理掉
  raw = raw.replace(/\s+/g, ' ');

  // 用中文 / 英文句號、問號、驚嘆號切句，保留標點在句尾
  const rawSentences = raw.split(/(?<=[。！？!?])/);
  const sentences = rawSentences
    .map(s => s.trim())
    .filter(Boolean);

  if (sentences.length === 0) return '';

  // 如果總長本來就不超過 maxChars，就直接回傳
  const fullText = sentences.join('');
  if (fullText.length <= maxChars) {
    return fullText;
  }

  const selected = [];
  let length = 0;

  const tryAdd = (s) => {
    if (!s) return;
    if (length + s.length > maxChars) return;
    selected.push(s);
    length += s.length;
  };

  // 1️⃣ 優先加入開頭 1～2 句（導言通常最重要）
  if (sentences[0]) tryAdd(sentences[0]);
  if (sentences[1]) tryAdd(sentences[1]);

  // 2️⃣ 再挑有「時間 / 人數 / 地點 / 官方單位」等關鍵資訊的句子
  const keywordRegex = /(今日|昨天|上午|下午|晚間|凌晨|稍早|今天|日前|[0-9０-９]+人|[0-9０-９]+名|[0-9０-９]+歲|[0-9０-９]+件|[0-9０-９]+萬元|台北|新北|台中|高雄|台南|桃園|新竹|花蓮|警方|醫院|學校|市府|年|月|日)/;

  sentences.forEach((s, idx) => {
    if (length >= maxChars) return;
    if (idx <= 1) return; // 前兩句已經考慮過
    if (keywordRegex.test(s)) {
      tryAdd(s);
    }
  });

  // 3️⃣ 如果還有空間，就依原順序補上其他句子
  sentences.forEach((s) => {
    if (length >= maxChars) return;
    if (selected.includes(s)) return;
    tryAdd(s);
  });

  let result = selected.join('');

  // 確保最後有句號/問號/驚嘆號作為結尾，比較像完整一句話
  if (!/[。！？!?]$/.test(result)) {
    result += '。';
  }

  return result;
}


// 清除 AI 用語 / 贅詞
function cleanNewsScript(raw) {
  if (!raw) return '';

  const lines = raw
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter(Boolean);

  const filtered = lines.filter((line) => {
    return !(
      /作為.?AI/i.test(line) ||
      /作為一個?人工智慧/i.test(line) ||
      /身為.?AI/i.test(line) ||
      /我是一個?AI/i.test(line) ||
      /無法提供(醫療|法律)建議/.test(line) ||
      /不能替代專業(醫療|法律)/.test(line) ||
      /如果您有任何問題/.test(line) ||
      /如果你有任何問題/.test(line) ||
      /建議您尋求專業/.test(line) ||
      /僅供參考/.test(line) ||
      /感謝你的提問/.test(line) ||
      /感謝您的提問/.test(line) ||
      /回答你的問題是/.test(line) ||
      /回答您的問題是/.test(line) ||
      /超出我的能力範圍/.test(line)
    );
  });

  let cleaned = filtered.join('\n').trim();
  cleaned = cleaned.replace(/^(播報稿|新聞播報|以下是播報內容)[：:\s]*/i, '');
  return cleaned;
}




module.exports = {
    hasFullScript,
    shortenArticle,
    cleanNewsScript
};