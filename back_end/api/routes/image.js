const express = require('express')
const router = express.Router()
const { searchImage, insertImage, updateImage, deleteImage } = require('../middlewares/imageController');

// search
router.get('/', searchImage);

// insert
router.post('/', insertImage);

// update
router.put('/', async (req, res, next) => {
    res.send('This is the update route');
});

// delete
router.delete('/', deleteImage);
router.delete('/:id', deleteImage);

module.exports = router