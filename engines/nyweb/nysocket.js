const WebSocket = require('ws');

function createWebSocketServer(server, onConnection) {
    const wss = new WebSocket.Server({ server });

    wss.on('connection', (ws) => {
        onConnection(ws);
    });
}

module.exports = {
    createWebSocketServer,
};
