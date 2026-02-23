const path = require('path');
const fs = require('fs');
const serverPath = path.join(__dirname, '..', 'packages/nyx-server/index.js');
const netPath = path.join(__dirname, '..', 'packages/nyx-net/index.js');

if (!fs.existsSync(serverPath) || !fs.existsSync(netPath)) {
    console.log('[SKIP] nyx-server or nyx-net package not available in this checkout');
    process.exit(0);
}

const serverPkg = require(serverPath);
const netPkg = require(netPath);

async function test() {
    console.log('--- Testing nyx-server ---');
    const app = serverPkg.create();
    const port = 3456;

    app.get('/hello', (req, res) => res.send('world'));
    app.post('/data', (req, res) => res.status(201).json(req.body));

    await app.start(port);
    console.log(`Server running on ${port}`);

    try {
        const r1 = await netPkg.get(`http://localhost:${port}/hello`);
        if (r1.data !== 'world') throw new Error('GET failed');
        console.log('GET /hello passed');

        const r2 = await netPkg.post(`http://localhost:${port}/data`, { a: 1 });
        if (r2.status !== 201 || r2.data.a !== 1) throw new Error('POST failed');
        console.log('POST /data passed');
        
        console.log('All nyx-server tests passed.');
    } catch(e) {
        console.error('TEST FAILED:', e.message);
        process.exit(1);
    } finally {
        app.stop();
    }
}
test();
