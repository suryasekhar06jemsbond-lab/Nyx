const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const rootDir = __dirname;
const repoRoot = path.join(__dirname, '..');

const scripts = [
    { name: 'Standard Library (Math, String, FS, JSON, Date, Color)', path: path.join(rootDir, 'test-all.js') },
    { name: 'Network Package', path: path.join(rootDir, 'test-net.js') },
    { name: 'Server Package', path: path.join(rootDir, 'test-server.js'), optional: true },
    { name: 'Package Manager (NYPM)', path: path.join(rootDir, 'test-nypm.js') }
];

console.log('========================================');
console.log('   RUNNING FULL NYX LANGUAGE TEST SUITE   ');
console.log('========================================\n');

let failures = 0;

scripts.forEach(script => {
    console.log(`[TEST] Running ${script.name}...`);
    try {
        if (!fs.existsSync(script.path)) {
            if (script.optional) {
                console.log(`[SKIP] ${script.name} (missing: ${script.path})\n`);
                return;
            }
            throw new Error(`File not found: ${script.path}`);
        }
        // Run script synchronously, inheriting stdio so we see the output
        execSync(`node "${script.path}"`, { stdio: 'inherit', cwd: rootDir });
        console.log(`[PASS] ${script.name}\n`);
    } catch (error) {
        console.error(`[FAIL] ${script.name}\n`);
        failures++;
    }
});

if (failures === 0) {
    console.log('========================================');
    console.log('   ALL TESTS PASSED SUCCESSFULLY   ');
    console.log('========================================');
    process.exit(0);
} else {
    console.error('========================================');
    console.error(`   ${failures} TEST(S) FAILED   `);
    console.error('========================================');
    process.exit(1);
}
