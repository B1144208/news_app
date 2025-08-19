const express = require('express')
const router = express.Router()
const { searchUser, insertUser, updateUser, deleteUser } = require('../middlewares/userController');
const { searchUserAction, insertUserAction, updateUserAction, deleteUserAction } = require('../middlewares/actionController');
const { getClientIp } = require('../utils/clientHelper')
const { checkPassword, hashPassword } = require('../utils/passwordHelper');

// search
router.get('/', searchUser);
router.get('/:id', searchUser);

// login / signup
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

// user_action
router.get('/:actionType/:dataType', searchUserAction);
router.post('/:actionType/:dataType', getClientIp, insertUserAction);    // ip
router.put('/:actionType/:dataType', updateUserAction);
router.delete('/:actionType/:dataType', deleteUserAction);






module.exports = router