const express = require('express')
const router = express.Router()
const { eventsortingCuration, multipleperspectivesCuration } = require('../middlewares/curationController')

// getData
router.post('/eventsorting', eventsortingCuration);
router.post('/multipleperspectives', multipleperspectivesCuration);

module.exports = router