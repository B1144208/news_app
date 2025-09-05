const express = require('express')
const router = express.Router()
const { searchGroupcustomize, insertGroupcustomize, updateGroupcustomize, updateGroupOrder, deleteGroupcustomize } = require('../middlewares/groupcustomizeController')

// search
router.get('/', searchGroupcustomize );
router.get('/:kind', searchGroupcustomize );

// insert
router.post('/', insertGroupcustomize);
router.post('/:kind', insertGroupcustomize);

// update
router.put('/', updateGroupcustomize);
router.put('/:kind', updateGroupcustomize);
router.put('/order/:kind', updateGroupOrder);  // general(groupcustomize_general), reset(groupcustomize_general), bookmark(groupcustomize_bookmark), data(group_data)

// delete
router.delete('/', deleteGroupcustomize);
router.delete('/:kind', deleteGroupcustomize);

module.exports = router