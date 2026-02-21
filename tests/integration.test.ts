import * as fs from 'fs';
import * as path from 'path';
import { execSync } from 'child_process';

const rootDir = path.join(__dirname, '..', '..'); // dist/tests -> root
const buildDir = path.join(rootDir, 'build');
const nativeDir = path.join(rootDir, 'native');
const nyxExe = path.join(buildDir, process.platform === 'win32' ? 'nyx.exe' : 'nyx');

function log(msg: string) {
    console.log(`\x1b[36m[Test]\x1b[0m ${msg}`);
}

function run(cmd: string) {
    log(`Running: ${cmd}`);
    execSync(cmd, { cwd: rootDir, stdio: 'inherit' });
}

async function main() {
    try {
        log('Starting Integration Tests...');

        // 1. Ensure directories exist
        if (!fs.existsSync(buildDir)) fs.mkdirSync(buildDir, { recursive: true });
        if (!fs.existsSync(nativeDir)) fs.mkdirSync(nativeDir, { recursive: true });

        // 2. Run Bootstrap (already compiled by npm run test pre-req)
        // This generates native/nyx.c
        log('Verifying bootstrap generation...');
        if (!fs.existsSync(path.join(nativeDir, 'nyx.c'))) {
            throw new Error('Bootstrap failed: native/nyx.c not found');
        }

        // 3. Compile C Runtime
        log('Compiling runtime...');
        try {
            // Try make first
            run('make');
        } catch (e) {
            log('Make failed or not found, attempting direct gcc compilation...');
            run(`gcc -O2 -std=c99 -o build/nyx native/nyx.c`);
        }

        // 4. Verify Executable
        if (!fs.existsSync(nyxExe)) {
            throw new Error(`Executable not found at ${nyxExe}`);
        }

        // 5. Run Functional Test
        const testScript = path.join(rootDir, 'tests', 'hello.ny');
        fs.writeFileSync(testScript, 'print("TEST_PASS");');
        
        const output = execSync(`"${nyxExe}" "${testScript}"`, { encoding: 'utf8' });
        if (output.includes('TEST_PASS')) {
            console.log('\x1b[32m✅ TESTS PASSED: Runtime is functioning correctly.\x1b[0m');
        } else {
            throw new Error(`Unexpected output: ${output}`);
        }

    } catch (err) {
        console.error('\x1b[31m❌ TESTS FAILED\x1b[0m', err);
        process.exit(1);
    }
}

main();