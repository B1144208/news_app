const express = require('express')
const router = express.Router()
const { searchChannel, insertChannel, updateChannel, deleteChannel } = require('../middlewares/channelController');
const { batchChannel } = require('../utils/batchHelper');

// search
router.get('/', searchChannel);

// insert
router.post('/', insertChannel);
router.post('/batch', batchChannel);

// update
router.put('/', async (req, res, next) => {
    res.send('This is the update route');
});

// delete
router.delete('/:id', deleteChannel);


module.exports = router