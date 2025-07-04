exports.secureHandler = (req, res) => {
    res.json({message: '你通過驗證了，歡迎進入保護區域！'});
}