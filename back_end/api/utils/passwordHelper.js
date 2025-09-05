const bcrypt = require('bcrypt');
const { checkRequireField } = require('./checkHelper');

// signup
async function hashPassword (req, res, next) {
    const plainPassword = req.password?.plainPassword;
    // 檢查必要欄位 & 格式 - plainPassword
    try {
        let result = await checkRequireField ([
            { field: 'plainPassword' , data: plainPassword , type: 'string' , other: ['non_null', 'non_change'] }
        ]);
    } catch (err) {
        err.desc = "middlewares-hashPassword(): Missing or Invalid required fields";
        return next(err);
    }
    const saltRounds = 10;
    const hashedPassword = await bcrypt.hash ( plainPassword, saltRounds);
    return res.apiSuccess({hashedPassword: hashedPassword}, "Hash Success");

}

// login
async function checkPassword ( req, res, next ) {
    const { plainPassword, hashedPassword } = req.password;
    let correctPassword = await bcrypt.compare( plainPassword, hashedPassword );
    if ( correctPassword ) return res.apiSuccess ( { success: true }, "Check Password Success" );
    return res.apiSuccess ( { success: false }, "Check Password Success" );
}

module.exports = { hashPassword, checkPassword };