const express = require('express')
const router = express.Router()
const { getGroup, getLocation } = require('../customModules/config/getData')

// getData
router.get('/group', getGroup);
router.get('/location', getLocation);

module.exports = router