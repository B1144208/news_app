const express = require('express')
const router = express.Router()
const { incrementFn } = require('../middlewares/incrementController')

// increment
// dataType : news, channel, eventsorting, multipleperspectives
// increType:  view, recent_view, share
router.post('/:dataType/:increType/:dataTypeId', incrementFn );





module.exports = router