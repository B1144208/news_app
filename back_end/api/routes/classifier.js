const express = require('express')
const router = express.Router()
const { getGroup, getLocation } = require('../customModules/config/getData')
const { newsClassifier, newsAllClassfier, newsGroupClassifier, newsLocationClassifier, newsKeywordClassifier } = require('../middlewares/classifierController')


// getData
router.get('/group', getGroup);
router.get('/location', getLocation);

// news-classifier
router.post('/all', newsAllClassfier);
router.post('/group', newsGroupClassifier);
router.post('/location', newsLocationClassifier);
router.post('/keyword', newsKeywordClassifier);

module.exports = router