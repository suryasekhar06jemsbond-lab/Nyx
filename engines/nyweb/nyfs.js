const fs = require('fs');
const crypto = require('crypto');

function exists(path) {
    return fs.existsSync(path);
}

function is_directory(path) {
    return fs.statSync(path).isDirectory();
}

function read(path) {
    return fs.readFileSync(path, 'utf8');
}

function md5(path) {
    const data = fs.readFileSync(path);
    return crypto.createHash('md5').update(data).digest('hex');
}

module.exports = {
    exists,
    is_directory,
    read,
    md5,
};
