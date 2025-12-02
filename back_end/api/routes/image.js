const express = require('express')
const router = express.Router()
const { searchImage, insertImage, updateImage, deleteImage, proxyImage } = require('../middlewares/imageController');

// ========== 新增：圖片代理端點 ==========
// 這個路由要放在最前面,避免被其他路由匹配
router.get('/proxy', proxyImage);

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