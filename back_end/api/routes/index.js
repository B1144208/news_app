const express = require('express');
const router = express.Router();

/*
const checkToken = require('../middlewares/authMiddleware');
const controller = require('../controllers/exampleController');

// 加入中介層
// 驗證 Authorization
router.get('/secure', checkToken, controller.secureHandler);
*/

// 測試 api
router.get('/', (req, res) => {
    res.send('Hello, Api!');
});

// 路由模組
const newsRouter = require('./news')
const channelRouter = require('./channel')
const imageRouter = require('./image')
const groupRouter = require('./group')

// 使用模組
router.use('/news', newsRouter)
router.use('/channel', channelRouter)
router.use('/image', imageRouter)
router.use('/group', groupRouter)

module.exports = router;