const pool = require('../connect_db');
const { checkRequireField } = require('../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');

// search
async function incrementFn (req, res, next) {
    /*
    @ dataType : news, channel, eventsorting, multipleperspectives
    @ increType: view, recent_view, share
    */
    const { dataType, increType, dataTypeId } = req.params ?? {};
    try {
        const [result] = await pool.query(`
            UPDATE ${dataType}_data
            SET total_${increType} = total_${increType} + 1
            WHERE ${dataType}_id = ?
        `, [dataTypeId]);
        if (result.affectedRows === 0) {
            err.desc = "middlewares-incrementController(): Data Not Found";
            return next(err);
        }

        return res.apiSuccess({success: true}, "Increment Success");
        res.json({ success: true, message: 'Incremented by 1' });
    } catch (err) {
        err.desc = "middlewares-incrementController(): database increment error";
        return next(err);
    }
}



module.exports = {
    incrementFn
}