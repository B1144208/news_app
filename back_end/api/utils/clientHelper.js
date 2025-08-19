module.exports = {
    getClientInfo : (req, res, next) => {
        // 取得client ip
        const ip = req.headers['x-forwarded-for']?.split(',')[0].trim()
                || req.socket.remoteAddress
                || 'unknown';
        // IPv6 本機 ::1 轉成 IPv4 127.0.0.1
        const clientIp = ip==='::1'? '127.0.0.1': ip;

        // 整理 client 資訊
        req.clientInfo = {
            ip: clientIp,
            port: req.socket.remotePort,
            userAgent: req.headers['user-agent'] || '',
            headers: req.headers,
            method: req.method,
            url: req.originalUrl
        }
        // res.apiSuccess({ clientIp: clientIp }, "Success");
        next();
    },
    getClientIp : (req, res, next) => {
        // 取得client ip
        const ip = req.headers['x-forwarded-for']?.split(',')[0].trim()
                || req.socket.remoteAddress
                || 'unknown';
        // IPv6 本機 ::1 轉成 IPv4 127.0.0.1
        const clientIp = ip === '::1'? '127.0.0.1': ip;
        
        ( req.body? req.body: {} ).clientIp = clientIp;

        // return res.apiSuccess({ clientIp: clientIp }, "Success");
        next();
    }
}