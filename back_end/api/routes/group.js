const express = require('express')
const router = express.Router()
const { searchGroup, insertGroup, updateGroup, deleteGroup } = require('../middlewares/groupController')

// search
router.get('/', searchGroup);

// insert
router.post('/', insertGroup);
router.post('/other', insertGroup);

// update
router.put('/', async (req, res, next) => {
    res.send('This is the update route');
});

// delete
router.delete('/', async (req, res, next) => {
    res.send('This is the delete route');
});

module.exports = router