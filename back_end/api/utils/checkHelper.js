
async function checkImageFormat( img ) {

    // 若 img 不存在或不是 object，直接回傳 null
    if (!img || typeof img !== 'object') {
        return null;
    }

    const hasSrc = 'src' in img;
    const hasAlt = 'alt' in img;

    // 若沒有 src 或 src 是空的字串，回傳 null
    if (!hasSrc || !img.src || img.src.trim() === '') {
        return null;
    }

    // 如果沒有 alt，就補 null
    if (!hasAlt) {
        img.alt = null;
    }

    return img;
}

function formatDateTimeForSQL(input) {
    if (typeof input !== 'string') throw new Error('Invalid input: not a string');

    // 1. 把斜線換成 dash
    let str = input.replace(/\//g, '-');

    // 2. 確保有「空格」把日期時間分開（防止 `T` 之類）
    str = str.replace('T', ' ');

    // 3. 如果只到分鐘，自動補上秒數
    if (/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$/.test(str)) {
        str += ':00';
    }

    // 4. 驗證完整格式
    const dateTimeRegex = /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/;
    if (!dateTimeRegex.test(str)) {
        throw new Error('Invalid datetime format. Expected: YYYY-MM-DD HH:mm:ss');
    }

    return str;
}


module.exports = { checkImageFormat, formatDateTimeForSQL };

