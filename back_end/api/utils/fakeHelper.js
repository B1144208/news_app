// req & res
async function callAndCatchApiSuccess(middlewareFn, fakeReq) {
    let data;
    
    const fakeRes = {
        apiSuccess: (resData) => data = resData,
        apiError: (err) => { throw err }
    };

    const fakeNext = (err) => {
        throw err;
    };

    await middlewareFn(fakeReq, fakeRes, fakeNext);
    return data;
}

module.exports = { callAndCatchApiSuccess }