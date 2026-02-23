const path = require('path');
const fs = require('fs');
const netPath = path.join(__dirname, '..', 'packages/nyx-net/index.js');

if (!fs.existsSync(netPath)) {
    console.log('[SKIP] nyx-net package not available in this checkout');
    process.exit(0);
}

const netPkg = require(netPath);

async function runTests() {
    console.log('--- Testing nyx-net Package ---');

    try {
        // Test GET
        console.log('\n> Testing GET...');
        const getRes = await netPkg.get('https://jsonplaceholder.typicode.com/posts/1');
        console.log(`Status: ${getRes.status}`);
        if (getRes.status !== 200) throw new Error(`GET failed with status ${getRes.status}`);
        if (getRes.data.id !== 1) throw new Error(`GET failed: Unexpected data`);
        console.log('GET passed.');

        // Test POST
        console.log('\n> Testing POST...');
        const postData = { title: 'foo', body: 'bar', userId: 1 };
        const postRes = await netPkg.post('https://jsonplaceholder.typicode.com/posts', postData);
        console.log(`Status: ${postRes.status}`);
        if (postRes.status !== 201) throw new Error(`POST failed with status ${postRes.status}`);
        console.log('POST passed.');

        // Test PUT
        console.log('\n> Testing PUT...');
        const putData = { id: 1, title: 'foo', body: 'bar', userId: 1 };
        const putRes = await netPkg.put('https://jsonplaceholder.typicode.com/posts/1', putData);
        console.log(`Status: ${putRes.status}`);
        if (putRes.status !== 200) throw new Error(`PUT failed with status ${putRes.status}`);
        console.log('PUT passed.');

        // Test DELETE
        console.log('\n> Testing DELETE...');
        const delRes = await netPkg.delete('https://jsonplaceholder.typicode.com/posts/1');
        console.log(`Status: ${delRes.status}`);
        if (delRes.status !== 200) throw new Error(`DELETE failed with status ${delRes.status}`);
        console.log('DELETE passed.');

        console.log('\n--- All nyx-net tests passed successfully ---');

    } catch (error) {
        const msg = String(error && error.message ? error.message : error);
        if (msg.toLowerCase().includes('network') || msg.toLowerCase().includes('fetch') || msg.toLowerCase().includes('timeout') || msg.toLowerCase().includes('enotfound')) {
            console.log(`\n[SKIP] Network unavailable: ${msg}`);
            process.exit(0);
        }
        console.error('\nTEST FAILED:', msg);
        process.exit(1);
    }
}

runTests();
