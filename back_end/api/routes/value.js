const express = require('express')
const router = express.Router()
const { searchValue, insertValue, updateValue, deleteValue } = require('../middlewares/valueController')

// search
router.get('/', searchValue);

// insert
router.post('/', insertValue);

// update
router.put('/', updateValue);

// delete
router.delete('/', deleteValue);
router.delete('/:type', deleteValue);

module.exports = router