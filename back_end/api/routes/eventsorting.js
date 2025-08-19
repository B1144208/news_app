const express = require('express')
const router = express.Router()
const { searchEventsorting, insertEventsorting, updateEventsorting, deleteEventsorting } = require('../middlewares/eventsortingController')

// search
router.get('/', searchEventsorting);

// insert
router.post('/', insertEventsorting);

// update
router.put('/', async (req, res, next) => {
    res.send('This is the update route');
});

// delete
router.delete('/', deleteEventsorting);
router.delete('/:id', deleteEventsorting);

module.exports = router