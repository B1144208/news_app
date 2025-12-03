const express = require('express')
const router = express.Router()
const { 
  searchChannel, 
  insertChannel, 
  updateChannel, 
  deleteChannel,
  getChannelById  // ✅ 新增导入
} = require('../middlewares/channelController');
const { batchChannel } = require('../utils/batchHelper');

// search
router.get('/', searchChannel);

// ✅ 新增：按 ID 获取单个频道（必须在通用 :id 路由前）
router.get('/:id', getChannelById);

// insert
router.post('/', insertChannel);
router.post('/batch', express.json({ limit: '10mb' }), batchChannel);

// update
router.put('/', async (req, res, next) => {
    res.send('This is the update route');
});

// delete
router.delete('/:id', deleteChannel);


module.exports = router