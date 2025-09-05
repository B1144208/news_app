
function generateUsername ( prefix='user' ) {
    /*
    @ user : 一般用戶
    @ anon : 匿名用戶
    @ guest: 無登入，短暫使用者
    */

    const letters = (Math.random().toString(26)+10).substring(2, 4); // 隨機2個小寫字母
    const numbers = Math.floor(Math.random()*100000).toString().padStart(5, '0');
    return `${prefix}_${letters}${numbers}`;
}

module.exports = { generateUsername };