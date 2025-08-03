const express = require('express')
const router = express.Router()
const { searchLocation, insertLocation, updateLocation, deleteLocation } = require('../middlewares/locationController');

// search
router.get('/', searchLocation);

// insert
router.post('/', insertLocation);

// update
router.put('/', async (req, res, next) => {
    res.send('This is the update route');
});

// delete
router.delete('/', async (req, res, next) => {
    res.send('This is the delete route');
});

module.exports = router