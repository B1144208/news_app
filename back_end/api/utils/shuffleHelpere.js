/**
 * 傳入一串 id 陣列，回傳亂數排序後的新陣列
 * @param {Array<number|string>} ids
 * @returns {Array<number|string>}
 */
function shuffleIds(ids) {
  if (!Array.isArray(ids)) return [];

  // 先複製一份，避免改到原始陣列
  const arr = ids.slice();

  // Fisher–Yates shuffle
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1)); // 0 ~ i
    [arr[i], arr[j]] = [arr[j], arr[i]];           // 交換
  }

  return arr;
}

function shuffleArray(arr) {
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}




module.exports = {
    shuffleIds,
    shuffleArray
}