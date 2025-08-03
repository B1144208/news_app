const express = require('express')
const router = express.Router()
const { searchChannel, insertChannel, updateChannel, deleteChannel } = require('../middlewares/channelController')

// search
router.get('/', searchChannel);

// insert
router.post('/', insertChannel);

// update
router.put('/', async (req, res, next) => {
    res.send('This is the update route');
});

// delete
router.delete('/:id', deleteChannel);


module.exports = router