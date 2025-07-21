//const mysql = require('mysql2');
const mysql = require('mysql2/promise')

/*const conn = mysql.createPool({
    host: 'localhost',
    user: 'root',
    password: '12345678',
    database: 'news',
    waitForConnections: true,
    connectionLimit: 100,
    queueLimit: 0
})*/

const pool = mysql.createPool({
    host: 'localhost',
    user: 'root',
    password: '12345678',
    database: 'news',
    multipleStatements: true,
    waitForConnections: true,
    connectionLimit: 100,
    queueLimit: 0
})

module.exports = pool;