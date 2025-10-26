const pool = require('../connect_db');
const { checkRequireField } = require('../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');

// search
async function searchGroupcustomize (req, res, next) {
    /*
    @ kind: name, bookmark
    @
    @ name    : groupcustomize_name
    @           參數 : name
    @ bookmark: groupcustomize_bookmark
    @           參數 : userId, groupId: []
    */
    let kind = req.params?.kind;
    let { userId, name, groupId } = req.body ?? {};

    // 檢查必要欄位 & 格式 - kind, userId, name
    try {
        [ kind, userId, name ] = await checkRequireField ([
            { field: 'kind'     , data: kind    , type: 'string' , other: ['non_null'], enum: ['name', 'bookmark', 'general'] },
            { field: 'userId'   , data: userId  , type: 'number' , other: ['lth']   },
            { field: 'name'     , data: name    , type: 'string' , other: ['lth']   },
            { field: 'groupId'  , data: groupId , type: 'array'  , other: ['lth', 'number_into_array'] , array_filter: "number" },
        ]);
    } catch (err) {
        err.desc = "middlewares-insertGroupcustomize(): Missing or Invalid required fields";
        return next(err);
    }

    // name search : name
    if ( kind==="name" ) {
        let sql = `
            SELECT *
            FROM groupcustomize_name
            WHERE 1
        `;
        let params = [];
        if ( name) {
            sql += ` AND groupcustomize_name = ?`
            params.push(name);
        }
        try {
            let [result] = await pool.query(sql, params);
            if ( result.length===0 )
                return res.apiSuccess({success: false}, "Search Not Found");
            if ( name ) return res.apiSuccess({success: true, searchId: result[0].groupcustomize_id}, "Search Success");
        return res.apiSuccess({success: true, result: result}, "Search Success");
        } catch (err) {
            err.desc = "middlewares-searchGroupcustomize(): database search error-name";
            return next(err);
        }
    }

    // bookmark search : groupId, userId
    if ( kind === "bookmark" ) {
        let sql = `
            SELECT *
            FROM groupcustomize_bookmark
            WHERE 1
        `;
        let params = [];
        if( groupId ) {
            let placeholders = groupId.map( ()=>'?').join(', ');
            sql += ` AND groupcustomize_id IN (${placeholders})`;
            params.push(...groupId);
        } else if ( userId ) {
            sql += ` AND user_id = ?`;
            params.push(userId);
        }
        try {
            let [result] = await pool.query(sql, params);
            if (result.length === 0)
                return res.apiSuccess ( {success: false, result:result}, "Search Not Found");
            //if ( groupId ) return res.apiSuccess ( {success: true, result:result}, "Search Success")
            
            return res.apiSuccess ( {success: true, result:result}, "Search Success");
            
        } catch (err) {
            err.desc = "middlewares-searchGroupcustomize(): database search error";
            return next(err);
        }
    }
}

// insert
async function insertGroupcustomize (req, res, next) {
    /*
    @ kind : name, bookmark, general
    @
    @ name    : bookmark 的 name
    @           參數 : name
    @ bookmark: user 自己增加
    @           參數 : userId, name, type, order
    @ general : news 的分類，user 創建時就要先匯入
    @           參數 : userId
    */

    let kind = req.params?.kind;
    let { userId, name, type, order } = req.body ?? {};

    // 檢查必要欄位 & 格式 - kind, userId, name, type, order
    try {
        [ kind, userId, name, type, order ] = await checkRequireField ([
            { field: 'kind'     , data: kind    , type: 'string' , other: ['non_null']  , enum: ['name', 'bookmark', 'general']                             },
            { field: 'userId'   , data: userId  , type: 'number' , other: ['lth']   },
            { field: 'name'     , data: name    , type: 'string' , other: ['lth']   },
            { field: 'type'     , data: type    , type: 'string' , other: ['lth']       , enum: ['news', 'channel', 'eventsorting','multipleperspectives']  },
            { field: 'order'    , data: order   , type: 'number' , other: ['lth']   },
        ]);
    } catch (err) {
        err.desc = "middlewares-insertGroupcustomize(): Missing or Invalid required fields";
        return next(err);
    }

    let invalidField = false;
    invalidField = ( (kind === 'name')? !name : false ) ||
                   ( (kind === 'bookmark')? ( !userId || !name || !type ) : false ) ||
                   ( (kind === 'general')? !userId : false )
    if ( invalidField ) {
        err = new Error("Missing or Invalid required fields");
        err.desc = "middlewares-updateUserAction(): Missing or Invalid required fields";
        return next(err);
    }

    // name insert
    if ( kind === "name" ) {
        // 先 search
        let fakeReq = {
            params: { kind: "name" },
            body: { name: name}
        }
        try {
            let searchGroupcustomizeResult = await callAndCatchApiSuccess ( searchGroupcustomize, fakeReq);
            if ( searchGroupcustomizeResult.success )
                return res.apiSuccess ( { insertId: searchGroupcustomizeResult.searchId }, "Search Success");
        } catch (err) {
            err.desc = "middlewares-insertGroupcustomize(): searchGroupcustomize error";
            return next (err);
        }

        // 再 insert
        let sql = `
            INSERT INTO groupcustomize_name ( groupcustomize_name )
            VALUES (?)
        `;
        let params = [name];
        try {
            let [result] = await pool.query(sql, params);
            return res.apiSuccess({ insertId: result.insertId }, "Insert Success");
        } catch (err) {
            err.desc = "middlewares-insertGroupcustomize(): database insert error - name";
            return next(err);
        }
    }

    // bookmark insert
    if ( kind === "bookmark" ) {

        let groupcustomizeId = null;
        // insert groupcustomize_name
        let fakeReq = {
            params: { kind: "name" },
            body: { name: name }
        }
        try {
            let insertGroupcustomizeResult = await callAndCatchApiSuccess (insertGroupcustomize, fakeReq );
            groupcustomizeId = insertGroupcustomizeResult.insertId;
        } catch (err) {
            err.desc = "middlewares-insertGroupcustomize(): insert groupcustomize_name error";
            return next(err);
        }
         
        // 找 order 的最大值
        let maxOrder = 0;
        if ( !order ) {
            sql = `
                SELECT MAX(groupcustomize_order) AS max_order
                FROM groupcustomize_bookmark
                WHERE user_id=? AND groupcustomize_type=?
            `;
            params = [userId, type];
            try {
                let [result] = await pool.query(sql, params);
                if ( result[0] ) maxOrder = result[0].max_order;
            } catch (err) {
                err.desc = "middlewares-insertGroupcustomize(): search max_order error";
                return next(err);
            }
        }

        // insert
        sql = `
            INSERT INTO groupcustomize_bookmark ( user_id, groupcustomize_name, groupcustomize_type, groupcustomize_order )
            VALUES (?, ?, ?, ?)
        `;
        params = [ userId, groupcustomizeId, type, order || maxOrder+10 ];
        try {
            let [result] = await pool.query(sql, params);
            return res.apiSuccess({ insertId: result.insertId }, "Insert Success");
        } catch (err) {
            err.desc = "middlewares-insertGroupcustomize(): database insert error - bookmark";
            return next(err);
        }
    }


    // general insert
    if ( kind === "general" ) {
        let sql = `
            SELECT group_id AS groupId 
            FROM group_data
            ORDER BY group_id;
        `;
        let params = [];
        let groupId = []
        try {
            let [result] = await pool.query(sql, params);
            result.map ( item => groupId.push(item.groupId) );
        } catch (err) {
            err.desc = "middlewares-insertGroupcustomize(): search group_id error";
            return next(err);
        }

        sql = `
            INSERT INTO groupcustomize_general ( user_id, group_id, group_order )
            VALUES 
        `;
        params = [];

        for ( let i=0; groupId[i]; i++ ) {
            (i==0)? sql += '(?, ?, ?)' : sql += ', (?, ?, ?)'
            params.push( userId, groupId[i], (i+1)*10 );
        }
        try {
            let [result] = await pool.query(sql, params);
            return res.apiSuccess(result, "Insert Success");
        } catch (err) {
            err.desc = "middlewares-insertGroupcustomize(): database insert error - general"
            return next(err);
        }
    }
}

// update
async function updateGroupcustomize(req, res, next) {
}
 

// update
async function updateGroupOrder(req, res, next) {
    /*
    @ kind : general, reset, bookmark, data
    @ general  (groupcustomize_general) : insert / update / delete / reset
    @       參數 : userId, groupOrder [ type, groupId, order ]
    @       type        : insert, update, delete, reset
    @       groupOrder  : [ [ type, groupId, order ], [ type, groupId, order ], ... ]
    @
    @ bookmark (groupcustomize_general) : insert / update / delete
    @       參數 : userId, groupOrder [ type, name, order ]
    @       type        : insert, update, delete
    @       groupOrder  : [ [ type, name, order ], [ type, name, order ], ... ]
    @       insert : insertGroupcustomize ['insert', groupcustomize_name(string), order]
    @       update : 直接 update          ['update', groupcustomize_id, order]
    @       delete : 直接 delete          ['delete', groupcustomize_id, null]
    @
    @ data     (group_data) : 
    @       參數 : groupIdList [ id, id, ... ]
    */
    let kind = req.params?.kind;
    let { userId, dataType, groupOrder, groupIdList } = req.body ?? {};
    
    // 檢查必要欄位 & 格式 - kind, userId, dataType, groupOrder, groupIdList
    try {
        [ kind, userId, dataType, groupOrder, groupIdList ] = await checkRequireField ([
            { field: 'kind'         , data: kind        , type: 'string' , other: ['non_null']  , enum: ["general", "reset", "bookmark", "data"] },
            { field: 'userId'       , data: userId      , type: 'number' , other: ['lth'] },
            { field: 'dataType'     , data: dataType    , type: 'string' , other: ['lth']       , enum: ["news", "channel", "eventsorting", "multipleperspectives"] },
            { field: 'groupOrder'   , data: groupOrder  , type: 'array'  , other: ['lth'] },
            { field: 'groupIdList'  , data: groupIdList , type: 'array'  , other: ['lth'] }
        ]);
    } catch (err) {
        err.desc = "middlewares-updateGroupOrder(): Missing or Invalid required fields";
        return next(err);
    }

    let invalidField = false;
    invalidField = ( (kind === 'general')? !userId || !groupOrder : false ) ||
                   ( (kind === 'reset')? !userId : false ) ||
                   ( (kind === 'bookmark')? !userId || !dataType || !groupOrder : false ) ||
                   ( (kind === 'data')? !groupIdList : false )
    if ( invalidField ) {
        err = new Error("Missing or Invalid required fields");
        err.desc = "middlewares-updateUserAction(): Missing or Invalid required fields";
        return next(err);
    }

    // general : groupcustomize_general order update ( insert/update/delete/reset )
    if ( kind === "general" || kind === "reset") {

        // 先search group_data 的 group_order
        let originOrder = new Map();   // group_id, group_order
        let sql = `
            SELECT group_id, group_order
            FROM group_data
        `;
        let params = [];
        try {
            let [result] = await pool.query(sql, params);

            // 存入 originOrder
            result.forEach ( item => {
                originOrder.set ( item.group_id, item.group_order ) // (key, value)
            });
        } catch (err) {
            err.desc = "middlewares-updateGroupOrder(): database search originOrder error - general";
            return next(err);
        }

        // reset 重寫 groupOrder
        if ( kind === "reset" ) {
            groupOrder = [];
            originOrder.forEach ( (order, id) => {       // (value, key, map)
                groupOrder.push(["insert", id, order]);
            });
        }

        // groupOrder 分解
        let groupOrderSql  = `group_order = CASE group_id`;
        let isDeleteSql    = `, is_delete = CASE group_id` , isDeleteParams = [];
        let groupIdSet = new Set();
        params = [];
        groupOrder.forEach ( ([type, groupId, order]) => {
            groupIdSet.add(groupId);

            // group_order
            groupOrderSql += ` WHEN ? THEN ?`;
            params.push(groupId, (type === "delete")? originOrder.get(groupId):order);

            // is_delete
            if ( type !== "update" ) {
                isDeleteSql += ` WHEN ? THEN ?`;
                isDeleteParams.push( groupId, type==="insert"? 0: 1 );
            }
        });
        groupOrderSql += ` END`;
        isDeleteSql += ` END`;
        let groupIdArray = Array.from(groupIdSet);
        let placeholders = groupIdArray.map(() => '?').join(', ');

        sql = `
            UPDATE groupcustomize_general
            SET 
                ${groupOrderSql}
                ${(isDeleteParams.length!==0)? isDeleteSql: ``}
            WHERE user_id=? AND group_id IN (${placeholders})
        `;
        params.push(...isDeleteParams, userId, ...groupIdArray);
        try {
            let [result] = await pool.query(sql, params);
            return res.apiSuccess(result, `Update Order Success - ${type}`);
        } catch (err) {
            err.desc = "middlewares-updateGroupOrder(): database update error-general";
            return next(err);
        }
    }

    // bookmark : group_data order update
    if ( kind === "bookmark" ) {
        let updateOrderSql  = `
            UPDATE groupcustomize_bookmark
            SET groupcustomize_order = CASE groupcustomize_id
        `;
        let updateOrderParams = [];
        let groupIdSet = new Set();
        let deleteIdSet = new Set();
        groupOrder.forEach( async ([type, name, order]) => {
            // insert 處理
            if (type === "insert") {
                let fakeReq = {
                    params: { kind: "bookmark" },
                    body: {
                        userId: userId,
                        name: name,
                        type: dataType,
                        order: order
                    }
                }
                try {
                    let [result] = await callAndCatchApiSuccess ( insertGroupcustomize, fakeReq );
                } catch (err) {
                    err.desc = "middlewares-updateGroupOrder(): database insert error-bookmark"
                }
            }
            // update
            if (type === "update") {
                updateOrderSql += ` WHEN ? THEN ?`;
                updateOrderParams.push( name, order );
                groupIdSet.add(name);
            }
            // delete
            if (type === "delete") {
                deleteIdSet.add(name);
            }
        })

        // update 處理
        let groupIdArray = Array.from(groupIdSet ?? []);
        if (groupIdArray.length===0) return res.apiSuccess({}, "Update Order Success - bookmark");
        let placeholders = groupIdArray.map(() => '?').join(', ');
        updateOrderSql += `
            END
            WHERE groupcustomize_id IN (${placeholders})
        `;
        updateOrderParams.push(...groupIdArray);
        try {
            let [result] = await pool.query(updateOrderSql, updateOrderParams);
        } catch (err) {
            err.desc = "middlewares-updateGroupOrder(): database update error-bookmark";
            return next(err);
        }

        // delete 處理
        let deleteIdArray = Array.from(deleteIdSet ?? []);
        if (deleteIdArray.length===0) return res.apiSuccess({}, "Update Order Success - bookmark");
        try {
            fakeReq = {
                params: { kind: "bookmark" },
                body: { id: deleteIdArray }
            }
            let deleteGroupcustomizeResult = await callAndCatchApiSuccess (deleteGroupcustomize, fakeReq);
        } catch (err) {
            err.desc = "middlewares-updateGroupOrder(): database delete error-bookmark";
            return next(err);
        }
        return res.apiSuccess({}, "Update Order Success - bookmark");
    }

    // data : group_data order update
    if ( kind === "data" ) {

        let sql  = `
            UPDATE group_data
            SET group_order = CASE group_id
        `;
        let params = [];

        for ( let i=0; groupIdList[i]; i++ ) {
            sql += ` WHEN ? THEN ?`;
            params.push(groupIdList[i], (i+1)*10 );
        }
        sql += ` END`;

        try {
            let [result] = await pool.query(sql, params);
            return res.apiSuccess( result, "Update Order Success" );
        } catch (err) {
            err.desc = "middlewares-updateGroupOrder(): database update error - data";
            return next(err);
        }

    }
    

}

// delete
async function deleteGroupcustomize(req, res, next) {
    /*
    @ kind    : name, bookmark
    @
    @ name    : 
    @           參數 : groupId
    @ bookmark: 
    @           參數 : groupId
    */
    let kind = req.params?.kind;
    let { groupId } = req.body ?? {};

    // 檢查必要欄位 & 格式 - kind, groupId
    try {
        [ kind, groupId ] = await checkRequireField ([
            { field: 'kind'     , data: kind    , type: 'string'    , other: ['non_null']  , enum: ["name", "bookmark"] },
            { field: 'groupId'  , data: groupId , type: 'array'     , other: ['non_null', 'number_into_array'] , array_filter: "number" }
        ]);
    } catch (err) {
        err.desc = "middlewares-deleteGroupcustomize(): Missing or Invalid required fields";
        return next(err);
    }


    let placeholders = groupId.map(()=>'?').join(', ');

    if (kind==="name") {
        // 先 search 有沒有被使用
        let fakeReq = {
            params: { kind: "bookmark" },
            body: { groupId: groupId }
        }
        let existGroupSet = new Set();
        try {
            let searchGroupcustomizeResult = await callAndCatchApiSuccess ( searchGroupcustomize, fakeReq );
            searchGroupcustomizeResult.result.map ( item => existGroupSet.add( item.groupcustomize_id ) );
        } catch (err) {
            err.desc = "middlewares-deleteGroupcustomize(): searchGroupcustomize error";
            return next(err);
        }
        groupId = groupId.filter( x=>!existGroupSet.has(x));

        placeholders = groupId.map(()=>'?').join(', ');
        
        // 再 delete
        sql = `
            DELETE FROM groupcustomize_name
            WHERE groupcustomize_id IN (${placeholders})
        `;
        params = [ ...groupId ];
        try {
            let [result] = await pool.query(sql, params);
            return res.apiSuccess({}, "Delete Success");
        } catch (err) {
            err.desc = "middlewares-deleteGroupcustomize(): database delete error";
            return next(err);
        }
    }

    if (kind==="bookmark") {
        let sql = `
            DELETE FROM groupcustomize_bookmark
            WHERE groupcustomize_id IN (${placeholders});
        `;
        let params = [...groupId];
        try {
            let [result] = await pool.query(sql, params);
            return res.apiSuccess(result, "Delete Success");
        } catch (err) {
            err.desc = "middlewares-deleteGroupcustomize(): database delete error";
            return next(err);
        }
    }
}

module.exports = {
    searchGroupcustomize,
    insertGroupcustomize,
    updateGroupcustomize,
    updateGroupOrder,
    deleteGroupcustomize
}