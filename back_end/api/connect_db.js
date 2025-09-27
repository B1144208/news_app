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

async function testConnection() {
    try {
        const connection = await pool.getConnection();
        console.log('Database connected successfully');
        connection.release();
    } catch (error) {
        console.error('Database connection failed:', error.message);
    }
}
testConnection();

module.exports = pool;
