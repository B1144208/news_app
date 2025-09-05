const express = require('express')
const router = express.Router()
const { searchRelation, insertRelation, updateRelation, deleteRelation } = require('../middlewares/relationController');

// search
router.get('/', searchRelation);

// insert
router.post('/', insertRelation);

// update
router.put('/', async (req, res, next) => {
    res.send('This is the update route');
});

// delete
router.delete('/', deleteRelation);
router.delete('/:id', deleteRelation);

module.exports = router