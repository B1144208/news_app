module.exports = (req, res, next) => {
    
    res.apiSuccess = (data = null, message = 'Success') => {
        return res.json({
            success: true,
            message,
            data
        });
    };

    res.apiError = (err, status = 500) => {
        return res.status(status).json({
            success: false,
            message: err.message || 'Unexpected error occurred',
            desc: err.desc || null,
            stack: err.stack || null
        });
    };

    next();
};