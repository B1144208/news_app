const pool = require('../connect_db');
const { checkRequireField } = require('../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');
const { checkPassword, hashPassword } = require('../utils/passwordHelper');
const { generateUsername } = require('../utils/randomHelper');
const { insertGroupcustomize } = require('./groupcustomizeController');

// ============================================
// 驗證碼系統配置（全局）
// ============================================
const verificationCodes = new Map();

const VERIFICATION_CONFIG = {
  codeLength: 6,
  codeExpiry: 5 * 60 * 1000,
  maxAttempts: 5,
  cooldownTime: 60 * 1000,
};

function generateVerificationCode(length = VERIFICATION_CONFIG.codeLength) {
  return Math.random()
    .toString()
    .substring(2, 2 + length)
    .padEnd(length, '0');
}

// insert
/*async function insertUser (req, res, next) {

    const { account, password } = req.body ?? {};
    let hashedPassword;

    // 檢查必要欄位 & 格式 - account, password
    try {
        let [ result] = await checkRequireField ([
            { field: 'account'  , data: account     , type: 'string'    , other: ['non_null', 'non_change'] },
            { field: 'password' , data: password    , type: 'string'    , other: ['non_null', 'non_change'] }
        ]);
    } catch (err) {
        err.desc = "middlewares-insertUser(): Missing or Invalid required fields";
        return next(err);
    }

    try {
        let fakeReq = {
            password: { plainPassword: password }
        };
        let result = await callAndCatchApiSuccess ( hashPassword, fakeReq );
        hashedPassword = result.hashedPassword;
    } catch (err) {
        err.desc = "middlewares-insertUser(): hashPassword error";
        return next(err);
    }

    let sql = `
        INSERT INTO user_profile ( user_account, user_password, user_name )
        VALUES ( ?, ?, ?)
    `
    let params = [ account, hashedPassword, generateUsername() ];
    let userId;
    try {
        let [result] = await pool.query( sql, params);
        userId = result.insertId;
    } catch (err) {
        err.desc = "middlewares-insertUser(): database insert error";
        return next(err);
    }
}*/

async function sendPhoneCode(phone, code) {
  console.log(`\n========== PHONE VERIFICATION CODE ==========`);
  console.log(`To: ${phone}`);
  console.log(`Code: ${code}`);
  console.log(`Valid for: ${VERIFICATION_CONFIG.codeExpiry / 1000} seconds`);
  console.log(`=============================================\n`);
  return true;
}

function getVerificationKey(target, type = 'email') {
  return `${type}:${target}`;
}

function getVerificationRecordKey(target, type = 'email') {
  return `${type}_record:${target}`;
}

// ============================================
// 原有功能（保持不變）
// ============================================

async function searchUser(req, res, next) {
  let id = req.params?.id;
  const login = req.originalUrl.includes('/login');
  const { account, password } = req.body ?? {};

  try {
    requireFields = [{ field: 'id', data: id, type: 'number' }];

    (!login && account) &&
      requireFields.push({
        field: 'account',
        data: account,
        type: 'string',
        other: ['non_null', 'non_change'],
      });

    login &&
      requireFields.push(
        {
          field: 'account',
          data: account,
          type: 'string',
          other: ['non_null', 'non_change'],
        },
        {
          field: 'password',
          data: password,
          type: 'string',
          other: ['non_null', 'non_change'],
        }
      );

    [id] = await checkRequireField(requireFields);
  } catch (err) {
    err.desc = 'middlewares-searchUser(): Missing or Invalid required fields';
    return next(err);
  }

  let sql = `
    SELECT *
    FROM user_profile
    WHERE 1
  `;
  params = [];

  if (id) {
    sql += ' AND user_id=?';
    params.push(id);
  } else if (account) {
    sql += ' AND user_account=?';
    params.push(account);
  }

  try {
    let [result] = await pool.query(sql, params);
    let user_id = null;
    let hashedPassword = null;

    if (result.length === 1) {
      user_id = result[0].user_id;
      hashedPassword = result[0].user_password;
    }

    if (login) {
      if (result.length === 1) {
        try {
          let fakeReq = {
            password: {
              plainPassword: password,
              hashedPassword: hashedPassword,
            },
          };
          let checkResult = await callAndCatchApiSuccess(
            checkPassword,
            fakeReq
          );

          return res.apiSuccess(
            {
              success: checkResult.success,
              userId: user_id,
            },
            checkResult.success ? 'Enter Correct' : 'Password Error'
          );
        } catch (err) {
          err.desc = 'middlewares-searchUser(): checkPassword error';
          return next(err);
        }
      } else {
        return res.apiSuccess({ success: false }, 'Account Error');
      }
    }
    return res.apiSuccess(result, 'Search Success');
  } catch (err) {
    err.desc = 'middlewares-searchUser(): database search error';
    return next(err);
  }
}

async function insertUser(req, res, next) {
  const { account, password } = req.body ?? {};
  let hashedPassword;

  try {
    let [result] = await checkRequireField([
      {
        field: 'account',
        data: account,
        type: 'string',
        other: ['non_null', 'non_change'],
      },
      {
        field: 'password',
        data: password,
        type: 'string',
        other: ['non_null', 'non_change'],
      },
    ]);
  } catch (err) {
    err.desc =
      'middlewares-insertUser(): Missing or Invalid required fields';
    return next(err);
  }

  try {
    let fakeReq = {
      password: { plainPassword: password },
    };
    let result = await callAndCatchApiSuccess(hashPassword, fakeReq);
    hashedPassword = result.hashedPassword;
  } catch (err) {
    err.desc = 'middlewares-insertUser(): hashPassword error';
    return next(err);
  }

  let userId = null;
  let sql = `
    INSERT INTO user_profile (user_account, user_password, user_name)
    VALUES (?, ?, ?)
  `;
  let params = [account, hashedPassword, generateUsername()];
  try {
    let [result] = await pool.query(sql, params);
    userId = result.insertId
  } catch (err) {
    err.desc = 'middlewares-insertUser(): database insert error';
    return next(err);
  }

  // insert groupcustomize order
  let fakeReq = {
      params: { kind: "general" },
      body: {userId: userId}
  };
  try {
      let insertGroupcustomizeResult = callAndCatchApiSuccess(insertGroupcustomize, fakeReq);
      return res.apiSuccess ( { insertId: userId }, "Insert Success");
  } catch (err) {
      err.desc = "middlewares-insertUser(): database groupcustomize insert error";
      return next(err);
  }
}

// ============================================
// 新增功能：updateUser（包含所有驗證API）
// ============================================

async function updateUser(req, res, next) {
  try {
    const { user_id, action } = req.body;

    if (!user_id) {
      // ✅ 改為 res.apiError()
      return res.apiError('用戶ID不能為空');
    }

    // 根據 action 類型執行不同操作
    switch (action) {
      case 'update-profile':
        return await updateProfile(req, res);
      case 'change-password':
        return await changePassword(req, res);
      case 'delete-account':
        return await deleteAccount(req, res);
      case 'send-email-code':
        return await sendEmailVerificationCode(req, res);
      case 'verify-email-code':
        return await verifyEmailCode(req, res);
      case 'send-phone-code':
        return await sendPhoneVerificationCode(req, res);
      case 'verify-phone-code':
        return await verifyPhoneCode(req, res);
      case 'update-location':
        return await updateLocationInfo(req, res);
      default:
        // ✅ 改為 res.apiError()
        return res.apiError('不支援的操作');
    }
  } catch (error) {
    console.error('updateUser 錯誤:', error);
    // ✅ 改為 res.apiError()
    return res.apiError('伺服器錯誤');
  }
}

/**
 * 更新個人資料
 */
async function updateProfile(req, res) {
  try {
    const { user_id, user_name, user_birthday, user_phone, user_email } =
      req.body;

    const [users] = await pool.query(
      'SELECT user_id FROM user_profile WHERE user_id = ?',
      [user_id]
    );

    if (users.length === 0) {
      // ✅ 改為 res.apiError()
      return res.apiError('用戶不存在');
    }

    const updateFields = [];
    const updateParams = [];

    if (user_name !== undefined && user_name !== null && user_name !== '') {
      updateFields.push('user_name = ?');
      updateParams.push(user_name);
    }

    if (user_birthday !== undefined && user_birthday !== null) {
      updateFields.push('user_birthday = ?');
      updateParams.push(user_birthday);
    }

    if (user_phone !== undefined && user_phone !== null && user_phone !== '') {
      updateFields.push('user_phone = ?');
      updateParams.push(user_phone);
    }

    if (user_email !== undefined && user_email !== null && user_email !== '') {
      const [existingEmails] = await pool.query(
        'SELECT user_id FROM user_profile WHERE user_email = ? AND user_id != ?',
        [user_email, user_id]
      );

      if (existingEmails.length > 0) {
        // ✅ 改為 res.apiError()
        return res.apiError('此郵箱已被使用');
      }

      updateFields.push('user_email = ?');
      updateParams.push(user_email);
    }

    if (updateFields.length === 0) {
      // ✅ 改為 res.apiError()
      return res.apiError('沒有要更新的資料');
    }

    updateParams.push(user_id);
    const sql = `UPDATE user_profile SET ${updateFields.join(
      ', '
    )} WHERE user_id = ?`;

    const [result] = await pool.query(sql, updateParams);

    if (result.affectedRows > 0) {
      // ✅ 改為 res.apiSuccess()，並添加 return
      return res.apiSuccess('個人資料更新成功');
    } else {
      // ✅ 改為 res.apiError()，並添加 return
      return res.apiError('更新失敗');
    }
  } catch (error) {
    console.error('updateProfile 錯誤:', error);
    // ✅ 改為 res.apiError()，並添加 return
    return res.apiError('伺服器錯誤: ' + error.message);
  }
}

/**
 * 修改密碼
 */
async function changePassword(req, res) {
  try {
    const { user_id, old_password, new_password } = req.body;

    if (!old_password || !new_password) {
      // ✅ 改為 res.apiError()
      return res.apiError('請提供原密碼和新密碼');
    }

    if (new_password.length < 6) {
      // ✅ 改為 res.apiError()
      return res.apiError('新密碼長度至少6位');
    }

    const [users] = await pool.query(
      'SELECT user_password FROM user_profile WHERE user_id = ?',
      [user_id]
    );

    if (users.length === 0) {
      // ✅ 改為 res.apiError()
      return res.apiError('用戶不存在');
    }

    const fakeReq = {
      password: {
        plainPassword: old_password,
        hashedPassword: users[0].user_password,
      },
    };

    const checkResult = await callAndCatchApiSuccess(checkPassword, fakeReq);

    if (!checkResult.success) {
      // ✅ 改為 res.apiError()
      return res.apiError('原密碼錯誤');
    }

    let fakeHashReq = {
      password: { plainPassword: new_password },
    };
    let hashResult = await callAndCatchApiSuccess(hashPassword, fakeHashReq);
    const hashedPassword = hashResult.hashedPassword;

    await pool.query(
      'UPDATE user_profile SET user_password = ? WHERE user_id = ?',
      [hashedPassword, user_id]
    );

    // ✅ 改為 res.apiSuccess()，並添加 return
    return res.apiSuccess('密碼修改成功');
  } catch (error) {
    console.error('修改密碼錯誤:', error);
    // ✅ 改為 res.apiError()，並添加 return
    return res.apiError('伺服器錯誤: ' + error.message);
  }
}

/**
 * 刪除帳號
 */
async function deleteAccount(req, res) {
  try {
    const { user_id, password } = req.body;

    const [users] = await pool.query(
      'SELECT user_password FROM user_profile WHERE user_id = ?',
      [user_id]
    );

    if (users.length === 0) {
      // ✅ 改為 res.apiError()
      return res.apiError('用戶不存在');
    }

    const fakeReq = {
      password: {
        plainPassword: password,
        hashedPassword: users[0].user_password,
      },
    };

    const checkResult = await callAndCatchApiSuccess(checkPassword, fakeReq);

    if (!checkResult.success) {
      // ✅ 改為 res.apiError()
      return res.apiError('密碼錯誤');
    }

    try {
      await pool.query('DELETE FROM user_profile WHERE user_id = ?', [user_id]);

      // ✅ 改為 res.apiSuccess()，並添加 return
      return res.apiSuccess('帳號已刪除');
    } catch (error) {
      throw error;
    }
  } catch (error) {
    console.error('刪除帳號錯誤:', error);
    // ✅ 改為 res.apiError()，並添加 return
    return res.apiError('刪除失敗: ' + error.message);
  }
}

/**
 * 發送郵箱驗證碼
 */
async function sendEmailVerificationCode(req, res) {
  try {
    const { user_id, email } = req.body;

    if (!email || !email.includes('@')) {
      // ✅ 改為 res.apiError()
      return res.apiError('請提供有效的郵箱地址');
    }

    const verifyKey = getVerificationKey(email, 'email');
    const recordKey = getVerificationRecordKey(email, 'email');

    const lastSent = verificationCodes.get(recordKey);
    if (
      lastSent &&
      Date.now() - lastSent.timestamp < VERIFICATION_CONFIG.cooldownTime
    ) {
      const remainingTime = Math.ceil(
        (VERIFICATION_CONFIG.cooldownTime - (Date.now() - lastSent.timestamp)) /
          1000
      );
      // ✅ 改為 res.apiError()
      return res.apiError(`請等待 ${remainingTime} 秒後重試`);
    }

    const code = generateVerificationCode();
    verificationCodes.set(verifyKey, {
      code,
      user_id,
      email,
      expiresAt: Date.now() + VERIFICATION_CONFIG.codeExpiry,
      attempts: 0,
    });

    verificationCodes.set(recordKey, {
      timestamp: Date.now(),
    });

    await sendEmailCode(email, code);

    // ✅ 改為 res.apiSuccess()，並添加 return
    return res.apiSuccess('驗證碼已發送，請檢查郵箱（開發環境：驗證碼已打印到控制台）');
  } catch (error) {
    console.error('發送郵箱驗證碼錯誤:', error);
    // ✅ 改為 res.apiError()，並添加 return
    return res.apiError('發送失敗: ' + error.message);
  }
}

/**
 * 驗證郵箱驗證碼
 */
async function verifyEmailCode(req, res) {
  try {
    const { user_id, email, code } = req.body;

    if (!email || !code) {
      // ✅ 改為 res.apiError()
      return res.apiError('郵箱和驗證碼不能為空');
    }

    const verifyKey = getVerificationKey(email, 'email');
    const record = verificationCodes.get(verifyKey);

    if (!record) {
      // ✅ 改為 res.apiError()
      return res.apiError('驗證碼已過期或不存在');
    }

    if (Date.now() > record.expiresAt) {
      verificationCodes.delete(verifyKey);
      // ✅ 改為 res.apiError()
      return res.apiError('驗證碼已過期');
    }

    if (record.attempts >= VERIFICATION_CONFIG.maxAttempts) {
      verificationCodes.delete(verifyKey);
      // ✅ 改為 res.apiError()
      return res.apiError('驗證次數過多，請重新發送驗證碼');
    }

    if (record.code !== code) {
      record.attempts++;
      // ✅ 改為 res.apiError()
      return res.apiError(
        `驗證碼錯誤（剩餘 ${
          VERIFICATION_CONFIG.maxAttempts - record.attempts
        } 次機會）`
      );
    }

    await pool.query(
      'UPDATE user_profile SET user_email = ? WHERE user_id = ?',
      [email, user_id]
    );

    verificationCodes.delete(verifyKey);
    verificationCodes.delete(getVerificationRecordKey(email, 'email'));

    // ✅ 改為 res.apiSuccess()，並添加 return
    return res.apiSuccess('郵箱驗證成功');
  } catch (error) {
    console.error('郵箱驗證錯誤:', error);
    // ✅ 改為 res.apiError()，並添加 return
    return res.apiError('驗證失敗: ' + error.message);
  }
}

/**
 * 發送手機驗證碼
 */
async function sendPhoneVerificationCode(req, res) {
  try {
    const { user_id, phone } = req.body;

    if (!phone || !phone.match(/^\d{10,15}$/)) {
      // ✅ 改為 res.apiError()
      return res.apiError('請提供有效的手機號碼');
    }

    const verifyKey = getVerificationKey(phone, 'phone');
    const recordKey = getVerificationRecordKey(phone, 'phone');

    const lastSent = verificationCodes.get(recordKey);
    if (
      lastSent &&
      Date.now() - lastSent.timestamp < VERIFICATION_CONFIG.cooldownTime
    ) {
      const remainingTime = Math.ceil(
        (VERIFICATION_CONFIG.cooldownTime - (Date.now() - lastSent.timestamp)) /
          1000
      );
      // ✅ 改為 res.apiError()
      return res.apiError(`請等待 ${remainingTime} 秒後重試`);
    }

    const code = generateVerificationCode();
    verificationCodes.set(verifyKey, {
      code,
      user_id,
      phone,
      expiresAt: Date.now() + VERIFICATION_CONFIG.codeExpiry,
      attempts: 0,
    });

    verificationCodes.set(recordKey, {
      timestamp: Date.now(),
    });

    await sendPhoneCode(phone, code);

    // ✅ 改為 res.apiSuccess()，並添加 return
    return res.apiSuccess('驗證碼已發送，請檢查簡訊（開發環境：驗證碼已打印到控制台）');
  } catch (error) {
    console.error('發送手機驗證碼錯誤:', error);
    // ✅ 改為 res.apiError()，並添加 return
    return res.apiError('發送失敗: ' + error.message);
  }
}

/**
 * 驗證手機驗證碼
 */
async function verifyPhoneCode(req, res) {
  try {
    const { user_id, phone, code } = req.body;

    if (!phone || !code) {
      // ✅ 改為 res.apiError()
      return res.apiError('手機號碼和驗證碼不能為空');
    }

    const verifyKey = getVerificationKey(phone, 'phone');
    const record = verificationCodes.get(verifyKey);

    if (!record) {
      // ✅ 改為 res.apiError()
      return res.apiError('驗證碼已過期或不存在');
    }

    if (Date.now() > record.expiresAt) {
      verificationCodes.delete(verifyKey);
      // ✅ 改為 res.apiError()
      return res.apiError('驗證碼已過期');
    }

    if (record.attempts >= VERIFICATION_CONFIG.maxAttempts) {
      verificationCodes.delete(verifyKey);
      // ✅ 改為 res.apiError()
      return res.apiError('驗證次數過多，請重新發送驗證碼');
    }

    if (record.code !== code) {
      record.attempts++;
      // ✅ 改為 res.apiError()
      return res.apiError(
        `驗證碼錯誤（剩餘 ${
          VERIFICATION_CONFIG.maxAttempts - record.attempts
        } 次機會）`
      );
    }

    await pool.query(
      'UPDATE user_profile SET user_phone = ? WHERE user_id = ?',
      [phone, user_id]
    );

    verificationCodes.delete(verifyKey);
    verificationCodes.delete(getVerificationRecordKey(phone, 'phone'));

    // ✅ 改為 res.apiSuccess()，並添加 return
    return res.apiSuccess('手機驗證成功');
  } catch (error) {
    console.error('手機驗證錯誤:', error);
    // ✅ 改為 res.apiError()，並添加 return
    return res.apiError('驗證失敗: ' + error.message);
  }
}

/**
 * 更新地點資訊
 */
async function updateLocationInfo(req, res) {
  try {
    const { user_id, location_country_id } = req.body;

    const countryIdToUpdate =
      location_country_id === 'null' || location_country_id === ''
        ? null
        : location_country_id;

    const sql = `
      UPDATE user_profile
      SET location_country_id = ?
      WHERE user_id = ?
    `;
    const params = [countryIdToUpdate, user_id];

    const [result] = await pool.query(sql, params);

    if (result.affectedRows === 0) {
      return res.json(
        apiSuccess(
          {
            updated: false,
            user_id: user_id,
            affectedRows: 0,
            changedRows: 0,
          },
          'Update Failed: User ID not found or Location is already set to this value.'
        )
      );
    }

    return res.json(
      apiSuccess(
        {
          updated: true,
          user_id: user_id,
          affectedRows: result.affectedRows,
          changedRows: result.changedRows,
        },
        'Update Success'
      )
    );
  } catch (error) {
    console.error('更新地點資訊錯誤:', error);
    // ✅ 改為 res.apiError()，並添加 return
    return res.apiError('伺服器錯誤: ' + error.message);
  }
}

async function deleteUser(req, res, next) {
  return;
}

module.exports = {
  searchUser,
  insertUser,
  updateUser,
  deleteUser,
};