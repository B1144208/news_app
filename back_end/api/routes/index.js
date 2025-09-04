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
const userRouter = require('./user')
//const { getClientInfo, getClientIp } = require('../utils/clientHelper')
const anonymousRouter = require('./anonymous');
const groupcustomizeRouter = require('./groupcustomize');

const newsRouter = require('./news')
const channelRouter = require('./channel')
const imageRouter = require('./image')
const groupRouter = require('./group')
const locationRouter = require('./location')
const relationRouter = require('./relation')
const keywordRouter = require('./keyword')
const eventsortingRouter = require('./eventsorting')
const multipleperspectivesRouter = require('./multipleperspectives')

const incrementRouter = require('./increment')
const valueRouter = require('./value')
const testRouter = require('./test')

// 使用模組
router.use('/user', userRouter)
//router.use('/user/ip', getClientIp, userRouter)
router.use('/anonymous', anonymousRouter);
router.use('/groupcustomize', groupcustomizeRouter);

router.use('/news', newsRouter)
router.use('/channel', channelRouter)
router.use('/image', imageRouter)
router.use('/group', groupRouter)
router.use('/location', locationRouter)
router.use('/relation', relationRouter)
router.use('/keyword', keywordRouter)
router.use('/eventsorting', eventsortingRouter)
router.use('/multipleperspectives', multipleperspectivesRouter)

router.use('/increment',incrementRouter)
router.use('/value', valueRouter)
router.use('/test', testRouter)

module.exports = router;