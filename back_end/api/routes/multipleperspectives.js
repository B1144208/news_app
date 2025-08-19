const express = require('express')
const router = express.Router()
const { searchMultipleperspectives, insertMultipleperspectives, updateMultipleperspectives, deleteMultipleperspectives } = require('../middlewares/multipleperspectivesController')

// search
router.get('/', searchMultipleperspectives);

// insert
router.post('/', insertMultipleperspectives);

// update
router.put('/', async (req, res, next) => {
    res.send('This is the update route');
});

// delete
router.delete('/', deleteMultipleperspectives);
router.delete('/:id', deleteMultipleperspectives);

module.exports = router