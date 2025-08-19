const express = require('express')
const router = express.Router()
const { searchAnonymous, insertAnonymous, updateAnonymous, deleteAnonymous } = require('../middlewares/anonymousController')

// search
router.get('/', searchAnonymous);

// insert
router.post('/', insertAnonymous);

// update
router.put('/', async (req, res, next) => {
    res.send('This is the update route');
});

// delete
router.delete('/', async (req, res, next) => {
    res.send('This is the delete route');
});

module.exports = router