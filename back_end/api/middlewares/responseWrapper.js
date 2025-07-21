module.exports = (req, res, next) => {
    
    res.apiSuccess = (data = null, message = '成功') => {
        res.json({
            success: true,
            message,
            data
        })
    };

    res.apiError = (err, status = 500) => {
        res.status(status).json({
            success: false,
            message: err.message || 'Unexpected error occurred',
            desc: err.desc || null,
            statck: err.stacl || null
        })
    };

    next();
};