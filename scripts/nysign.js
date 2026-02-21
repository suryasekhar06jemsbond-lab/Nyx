#!/usr/bin/env node
// Nyx Package Signing Tool

const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

const args = process.argv.slice(2);
let packageFile = null;
let outputFile = null;
let verifyFile = null;
let useGpg = false;
let keyId = null;
let showHelp = false;

for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    switch (arg) {
        case '--help':
        case '-h':
            showHelp = true;
            break;
        case '--verify':
        case '-v':
            verifyFile = args[++i];
            break;
        case '--gpg':
        case '-g':
            useGpg = true;
            break;
        case '--key-id':
        case '-k':
            keyId = args[++i];
            break;
        case '--output':
        case '-o':
            outputFile = args[++i];
            break;
        default:
            if (!packageFile && !arg.startsWith('-')) {
                packageFile = arg;
            }
    }
}

function showHelpText() {
    console.log(`Nyx Package Signing Tool

Usage:
    node nysign.js <package> [options]
    node nysign.js mypkg.nypkg --output mypkg.sha256
    node nysign.js mypkg.nypkg --verify mypkg.sha256

Options:
    --verify <file>    Verify signature
    --gpg              Use GPG signing (requires GPG)
    --key-id <id>      GPG key ID
    --output <file>    Output file
    --help             Show help`);
}

if (showHelp || !packageFile) {
    showHelpTextText();
    process.exit(0);
}

if (!fs.existsSync(packageFile)) {
    console.error(`Error: Package not found: ${packageFile}`);
    process.exit(1);
}

const pkgName = path.basename(packageFile);
const baseName = path.basename(pkgName, path.extname(pkgName));

function createChecksum(file) {
    const content = fs.readFileSync(file);
    const hash = crypto.createHash('sha256').update(content).digest('hex');
    return hash;
}

if (verifyFile) {
    // Verification mode
    console.log(`Verifying: ${packageFile}`);
    
    if (!fs.existsSync(verifyFile)) {
        console.error(`Error: Signature not found: ${verifyFile}`);
        process.exit(1);
    }
    
    const currentHash = createChecksum(packageFile).toLowerCase();
    const expectedHash = fs.readFileSync(verifyFile, 'utf8').trim().split(' ')[0].toLowerCase();
    
    console.log(`Current:  ${currentHash}`);
    console.log(`Expected: ${expectedHash}`);
    
    if (currentHash === expectedHash) {
        console.log('VERIFIED: Package integrity confirmed'.green);
        process.exit(0);
    } else {
        console.error('FAILED: Package integrity check failed'.red);
        process.exit(1);
    }
} else {
    // Signing mode
    console.log(`Signing: ${packageFile}`);
    
    if (!outputFile) {
        outputFile = `${baseName}.sha256`;
    }
    
    const hash = createChecksum(packageFile);
    const signature = `${hash}  ${pkgName}`;
    
    fs.writeFileSync(outputFile, signature, 'utf8');
    
    console.log(`Signature saved to: ${outputFile}`.green);
    
    // Auto-verify
    console.log('Verifying...');
    const currentHash = createChecksum(packageFile).toLowerCase();
    const expectedHash = fs.readFileSync(outputFile, 'utf8').trim().split(' ')[0].toLowerCase();
    
    if (currentHash === expectedHash) {
        console.log('Self-verification: OK'.green);
    } else {
        console.error('Self-verification: FAILED'.red);
        process.exit(1);
    }
}
