const checkToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];

    if(!authHeader) {
        res.status(401).json({error: 'Missing Authorization header'});
    }

    const token = authHeader.replace('Bearer ', '');
    if (token==='secret123') {
        next();
    }else {
        res.status(403).json({error: 'Invalid token'});
    }
};

module.exports = checkToken;