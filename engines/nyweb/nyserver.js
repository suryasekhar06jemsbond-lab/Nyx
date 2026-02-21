const http = require('http');
const WebSocket = require('ws');

function createServer(host, port, requestHandler, wsHandler) {
    const server = http.createServer(async (req, res) => {
        let body = '';
        req.on('data', chunk => {
            body += chunk.toString();
        });
        req.on('end', async () => {
            req.body = body;
            const response = await requestHandler(req);
            res.statusCode = response.status_code;
            for (const key in response.headers) {
                res.setHeader(key, response.headers[key]);
            }
            res.end(response.body);
        });
    });

    const wss = new WebSocket.Server({ server });

    wss.on('connection', (ws, req) => {
        wsHandler(ws, req);
    });

    server.listen(port, host, () => {
        console.log(`Server running at http://${host}:${port}/`);
    });

    return server;
}

module.exports = {
    createServer,
};
