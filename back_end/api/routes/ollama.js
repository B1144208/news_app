const express = require('express')
const router = express.Router()
const { getGroup, getLocation } = require('../customModules/config/getData')
const { newsClassifier } = require('../middlewares/ollamaController')

// getData
router.get('/group', getGroup);
router.get('/location', getLocation);

// news-classifier
router.post('/news-classifier', newsClassifier);

module.exports = router