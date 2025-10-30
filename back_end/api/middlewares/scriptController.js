const pool = require('../connect_db');
const { checkRequireField } = require('../utils/checkHelper');
const { callAndCatchApiSuccess } = require('../utils/fakeHelper');

// search
async function generalScript (req, res, next) {
    return;
}

// insert
async function reporterScript (req, res, next) {
    return;
}

// update
async function chatScript(req, res, next) {
    return;
}

// delete
async function quickScript(req, res, next) {
    return;
}

module.exports = {
    generalScript,
    reporterScript,
    chatScript,
    quickScript
}