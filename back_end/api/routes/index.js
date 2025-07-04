const express = require('express');
const router = express.Router();

const checkToken = require('../middlewares/authMiddleware');
const controller = require('../controllers/exampleController');

// 加入中介層
// 驗證 Authorization
router.get('/secure', checkToken, controller.secureHandler);

module.exports = router;