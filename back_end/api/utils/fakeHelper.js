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

function callAndCatchApiSuccessInGeneralFunction(handler, fakeReq) {
  return new Promise((resolve, reject) => {
    const fakeRes = {
      status(code) {
        this.statusCode = code;
        return this;
      },
      json(body) {
        // 這裡把 controller 回來的資料丟給 resolve
        resolve(body.data ?? body);
      },
    };
    const fakeNext = (err) => err ? reject(err) : null;

    handler(fakeReq, fakeRes, fakeNext);
  });
}

module.exports = { callAndCatchApiSuccess, callAndCatchApiSuccessInGeneralFunction }