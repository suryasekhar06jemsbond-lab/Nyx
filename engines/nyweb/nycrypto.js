const crypto = require('crypto');
const jwt = require('jsonwebtoken');

function hmac_sha256(secret, data) {
    return crypto.createHmac('sha256', secret).update(data).digest('hex');
}

function sign(payload, secret, options) {
    return jwt.sign(payload, secret, options);
}

function verify(token, secret, options) {
    try {
        return { valid: true, payload: jwt.verify(token, secret, options) };
    } catch (error) {
        return { valid: false, error: error.message };
    }
}

function b64url_encode(data) {
    return Buffer.from(data)
        .toString('base64')
        .replace(/\+/g, '-')
        .replace(/\//g, '_')
        .replace(/=/g, '');
}

function b64url_decode(data) {
    data = data.replace(/-/g, '+').replace(/_/g, '/');
    while (data.length % 4) {
        data += '=';
    }
    return Buffer.from(data, 'base64').toString();
}

module.exports = {
    hmac_sha256,
    sign,
    verify,
    b64url_encode,
    b64url_decode,
};
