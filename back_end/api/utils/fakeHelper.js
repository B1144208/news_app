// req & res
async function callAndCatchApiSuccess(middlewaresFn, fakeReq) {
    let data;
    
    const fakeRes = {
        apiSuccess: (resData) => data = resData,
        apiError: (err) => { throw err }
    };

    const fakeNext = (err) => {
        throw err;
    };

    await middlewaresFn(fakeReq, fakeRes, fakeNext);
    return data;
}

async function callAndCatchApiSuccessInGeneralFunction(handler, fakeReq = {}) {
  return new Promise((resolve, reject) => {
    // 這就是給 controller 用的「假 res」
    const fakeRes = {
      // 你的 controller 裡用的是 res.apiSuccess(data, message)
      apiSuccess(data, message) {
        // 只把 data 回傳給外面用
        resolve(data);
      },

      // 萬一有 controller 用到 apiFail 之類的
      apiFail(err, message) {
        reject(err || new Error(message || 'apiFail'));
      },

      // 如果某些 controller 用 res.status().json()，這裡也做個簡單的備援
      status(code) {
        this._status = code;
        return this;
      },
      json(payload) {
        resolve(payload);
      }
    };

    const next = (err) => {
      if (err) return reject(err);
      // 沒錯誤又沒有呼叫 apiSuccess/json 的話，就卡在這裡，
      // 一般來說不會發生；真的發生就回傳 undefined
      resolve(undefined);
    };

    try {
      handler(fakeReq, fakeRes, next);
    } catch (err) {
      reject(err);
    }
  });
}

module.exports = { callAndCatchApiSuccess, callAndCatchApiSuccessInGeneralFunction }