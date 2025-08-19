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

module.exports = { callAndCatchApiSuccess }