const express = require('express')
const router = express.Router()
const { searchUser, insertUser, updateUser, deleteUser } = require('../middlewares/userController');
const { checkPassword, hashPassword } = require('../utils/passwordHelper');

// search
router.get('/', searchUser);
router.get('/:id', searchUser);

// insert
router.post('/login', searchUser);
router.post('/signup', insertUser);

// update
router.put('/', async (req, res, next) => {
    res.send('This is the update route');
});

// delete
router.delete('/', async (req, res, next) => {
    res.send('This is the delete route');
});





module.exports = router