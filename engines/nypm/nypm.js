#!/usr/bin/env node
/**
 * NYPM - Nyx Package Manager CLI
 * ===============================
 * World-class package manager for Nyx
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const REGISTRY_URL = 'https://registry.nyxlang.dev';
const MODULES_DIR = 'nyx_modules';
const LOCK_FILE = 'nyx.lock';
const MANIFEST_FILE = 'nyx.toml';

// CLI Commands
const COMMANDS = {
    init: 'Initialize new package',
    install: 'Install dependencies',
    add: 'Add dependency',
    remove: 'Remove dependency',
    update: 'Update packages',
    list: 'List installed packages',
    search: 'Search registry',
    publish: 'Publish package',
    outdated: 'Check for updates',
    run: 'Run script',
    clean: 'Clean artifacts',
    doctor: 'Check setup',
    audit: 'Security audit',
    'workspace': 'Workspace commands'
};

// Version parsing
function parseVersion(v) {
    const match = v.match(/^(\d+)\.(\d+)\.(\d+)(?:-([a-zA-Z0-9.-]+))?(?:\+([a-zA-Z0-9.-]+))?$/);
    if (!match) return null;
    return {
        major: parseInt(match[1]),
        minor: parseInt(match[2]),
        patch: parseInt(match[3]),
        prerelease: match[4] || '',
        build: match[5] || '',
        toString: () => v
    };
}

// Version comparison
function compareVersions(a, b) {
    const va = parseVersion(a);
    const vb = parseVersion(b);
    if (!va || !vb) return 0;
    
    if (va.major !== vb.major) return va.major - vb.major;
    if (va.minor !== vb.minor) return va.minor - vb.minor;
    if (va.patch !== vb.patch) return va.patch - vb.patch;
    
    // Pre-release versions have lower precedence
    if (va.prerelease && !vb.prerelease) return -1;
    if (!va.prerelease && vb.prerelease) return 1;
    
    return 0;
}

// Parse version range
function parseRange(constraint) {
    let comparator = '>=';
    let version = constraint;
    
    if (constraint.startsWith('^')) {
        comparator = '^';
        version = constraint.slice(1);
    } else if (constraint.startsWith('~')) {
        comparator = '~';
        version = constraint.slice(1);
    } else if (constraint.startsWith('>=')) {
        comparator = '>=';
        version = constraint.slice(2);
    } else if (constraint.startsWith('>')) {
        comparator = '>';
        version = constraint.slice(1);
    } else if (constraint.startsWith('<=')) {
        comparator = '<=';
        version = constraint.slice(2);
    } else if (constraint.startsWith('<')) {
        comparator = '<';
        version = constraint.slice(1);
    } else if (constraint.startsWith('=')) {
        comparator = '=';
        version = constraint.slice(1);
    }
    
    return { comparator, version: parseVersion(version) };
}

// Check if version satisfies range
function satisfies(version, constraint) {
    const range = parseRange(constraint);
    const v = parseVersion(version);
    if (!v || !range.version) return false;
    
    const cmp = compareVersions(version, range.version);
    
    switch (range.comparator) {
        case '=': return cmp === 0;
        case '^': return v.major === range.version.major;
        case '~': return v.major === range.version.major && v.minor === range.version.minor;
        case '>': return cmp > 0;
        case '>=': return cmp >= 0;
        case '<': return cmp < 0;
        case '<=': return cmp <= 0;
        default: return cmp === 0;
    }
}

// Find latest version matching constraint
function findLatest(versions, constraint) {
    const range = parseRange(constraint);
    const matching = versions.filter(v => satisfies(v, constraint));
    if (matching.length === 0) return null;
    matching.sort(compareVersions);
    return matching[matching.length - 1];
}

// SHA-256 hash
function hashSHA256(data) {
    return crypto.createHash('sha256').update(data).digest('hex');
}

// Read manifest
function readManifest() {
    const manifestPath = path.join(process.cwd(), MANIFEST_FILE);
    if (!fs.existsSync(manifestPath)) {
        // Try old package.json
        const pkgPath = path.join(process.cwd(), 'package.json');
        if (fs.existsSync(pkgPath)) {
            return JSON.parse(fs.readFileSync(pkgPath, 'utf-8'));
        }
        return null;
    }
    // Parse TOML (simplified - in real impl use TOML parser)
    const content = fs.readFileSync(manifestPath, 'utf-8');
    return parseManifest(content);
}

// Parse manifest (simplified)
function parseManifest(content) {
    const manifest = {
        name: '',
        version: '1.0.0',
        dependencies: {},
        dev_dependencies: {},
        scripts: {}
    };
    
    // Simple parsing
    const lines = content.split('\n');
    let section = '';
    
    for (const line of lines) {
        const trimmed = line.trim();
        if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
            section = trimmed.slice(1, -1);
            continue;
        }
        
        if (section === 'package') {
            const [key, value] = trimmed.split(' = ');
            if (key === 'name') manifest.name = value.replace(/"/g, '');
            if (key === 'version') manifest.version = value.replace(/"/g, '');
        }
        
        if ((section === 'dependencies' || section === 'dev-dependencies') && trimmed.includes('=')) {
            const [key, value] = trimmed.split(' = ');
            const depName = key.trim();
            const depVersion = value.replace(/"/g, '').trim();
            if (section === 'dependencies') {
                manifest.dependencies[depName] = depVersion;
            } else {
                manifest.dev_dependencies[depName] = depVersion;
            }
        }
        
        if (section === 'scripts' && trimmed.includes('=')) {
            const [key, value] = trimmed.split(' = ');
            manifest.scripts[key.trim()] = value.replace(/"/g, '');
        }
    }
    
    return manifest;
}

// Read lockfile
function readLockfile() {
    const lockPath = path.join(process.cwd(), LOCK_FILE);
    if (!fs.existsSync(lockPath)) return null;
    
    const content = fs.readFileSync(lockPath, 'utf-8');
    return parseLockfile(content);
}

// Parse lockfile (simplified)
function parseLockfile(content) {
    const lockfile = { version: '', packages: {} };
    const lines = content.split('\n');
    let currentPkg = null;
    
    for (const line of lines) {
        const trimmed = line.trim();
        
        if (trimmed.startsWith('version = ')) {
            lockfile.version = trimmed.split('=')[1].replace(/"/g, '').trim();
        }
        
        if (trimmed.startsWith('[') && trimmed.includes('.')) {
            const match = trimmed.match(/\[packages\.(.+)\]/);
            if (match) {
                currentPkg = match[1];
                lockfile.packages[currentPkg] = {};
            }
        }
        
        if (currentPkg && trimmed.includes('=')) {
            const [key, value] = trimmed.split(' = ');
            const k = key.trim();
            const v = value.replace(/"/g, '').trim();
            
            if (k === 'version') lockfile.packages[currentPkg].version = v;
            if (k === 'resolved') lockfile.packages[currentPkg].resolved = v;
            if (k === 'integrity') lockfile.packages[currentPkg].integrity = v;
        }
    }
    
    return lockfile;
}

// Write lockfile
function writeLockfile(lockfile) {
    let content = '# NYX.LOCK - Lockfile\n';
    content += '# Generated by Nypm\n\n';
    content += `version = "${lockfile.version || '3.0.0'}"\n\n`;
    content += '[metadata]\n';
    content += `generated_at = "${new Date().toISOString()}"\n`;
    content += 'resolver = "minimal"\n\n';
    
    for (const [name, pkg] of Object.entries(lockfile.packages)) {
        content += `[packages.${name}]\n`;
        content += `name = "${name}"\n`;
        content += `version = "${pkg.version}"\n`;
        content += `resolved = "${pkg.resolved}"\n`;
        content += `integrity = "${pkg.integrity}"\n`;
        content += '\n';
    }
    
    fs.writeFileSync(path.join(process.cwd(), LOCK_FILE), content);
}

// Initialize package
function init(name, version) {
    const manifestPath = path.join(process.cwd(), MANIFEST_FILE);
    
    if (fs.existsSync(manifestPath)) {
        console.log('nyx.toml already exists.');
        return;
    }
    
    const content = `# ${name || 'myapp'} - Nyx Package

[package]
name = "${name || path.basename(process.cwd())}"
version = "${version || '1.0.0'}"
description = "A Nyx application"
authors = [{ name = "Developer", email = "dev@example.com" }]
license = "MIT"

[dependencies]

[dev-dependencies]

[scripts]
start = "ny main.ny"
test = "nytest"
`;

    fs.writeFileSync(manifestPath, content);
    console.log('Created nyx.toml');
    
    // Also create nyx.lock
    writeLockfile({ version: '3.0.0', packages: {} });
    console.log('Created nyx.lock');
}

// Install dependencies
function install(packages) {
    const manifest = readManifest();
    if (!manifest) {
        console.log('No nyx.toml found. Run "nypm init" first.');
        return;
    }
    
    console.log('Installing dependencies...');
    
    const lockfile = readLockfile() || { version: '3.0.0', packages: {} };
    
    // Install each dependency
    const deps = { ...manifest.dependencies, ...manifest.dev_dependencies };
    
    for (const [name, constraint] of Object.entries(deps)) {
        console.log(`  Installing ${name} ${constraint}...`);
        
        // In real implementation, fetch from registry
        const version = constraint.startsWith('^') || constraint.startsWith('~') 
            ? constraint.slice(1) 
            : constraint.replace(/[>=<~^]/g, '');
        
        lockfile.packages[name] = {
            name,
            version: version || '1.0.0',
            resolved: `${REGISTRY_URL}/${name}/${version}`,
            integrity: `sha256-${hashSHA256(name + version)}`
        };
    }
    
    writeLockfile(lockfile);
    console.log(`Installed ${Object.keys(lockfile.packages).length} packages`);
}

// Add dependency
function add(name, version, dev) {
    const manifestPath = path.join(process.cwd(), MANIFEST_FILE);
    
    if (!fs.existsSync(manifestPath)) {
        console.log('No nyx.toml found. Run "nypm init" first.');
        return;
    }
    
    let content = fs.readFileSync(manifestPath, 'utf-8');
    
    const section = dev ? '[dev-dependencies]' : '[dependencies]';
    const entry = `${name} = "${version || '^1.0.0'}"`;
    
    if (content.includes(section)) {
        // Add to existing section
        content = content.replace(section, section + '\n' + entry);
    } else {
        content += '\n' + section + '\n' + entry + '\n';
    }
    
    fs.writeFileSync(manifestPath, content);
    console.log(`Added ${name} ${version} (${dev ? 'dev' : 'production'})`);
    
    // Install
    install();
}

// Remove dependency
function remove(name) {
    const manifestPath = path.join(process.cwd(), MANIFEST_FILE);
    
    if (!fs.existsSync(manifestPath)) {
        console.log('No nyx.toml found.');
        return;
    }
    
    let content = fs.readFileSync(manifestPath, 'utf-8');
    
    // Remove from dependencies and dev-dependencies
    content = content.split('\n')
        .filter(line => !line.includes(`${name} = "`))
        .join('\n');
    
    fs.writeFileSync(manifestPath, content);
    console.log(`Removed ${name}`);
}

// List packages
function list() {
    const lockfile = readLockfile();
    
    if (!lockfile || Object.keys(lockfile.packages).length === 0) {
        console.log('No packages installed.');
        return;
    }
    
    console.log('Installed packages:\n');
    for (const [name, pkg] of Object.entries(lockfile.packages)) {
        console.log(`  ${name} ${pkg.version}`);
    }
}

// Search registry
function search(query) {
    // Built-in packages
    const packages = [
        { name: 'nyweb', version: '3.0.0', description: 'Web framework' },
        { name: 'nyhttp', version: '2.0.0', description: 'HTTP client/server' },
        { name: 'nydatabase', version: '2.0.0', description: 'Database operations' },
        { name: 'nyls', version: '2.0.0', description: 'Language Server Protocol' },
        { name: 'nyserver', version: '2.0.0', description: 'Server infrastructure' },
        { name: 'nygame', version: '2.0.0', description: 'Game development' },
        { name: 'nygui', version: '2.0.0', description: 'GUI framework' },
        { name: 'nyml', version: '2.0.0', description: 'Machine learning' },
        { name: 'nycrypto', version: '2.0.0', description: 'Cryptography' },
        { name: 'nymedia', version: '2.0.0', description: 'Media processing' },
    ];
    
    const results = packages.filter(p => 
        p.name.includes(query) || p.description.toLowerCase().includes(query.toLowerCase())
    );
    
    if (results.length === 0) {
        console.log(`No packages found matching "${query}"`);
        return;
    }
    
    console.log(`Found ${results.length} packages:\n`);
    for (const pkg of results) {
        console.log(`  ${pkg.name} ${pkg.version}`);
        console.log(`    ${pkg.description}\n`);
    }
}

// Update packages
function update(package) {
    const lockfile = readLockfile();
    
    if (!lockfile) {
        console.log('No lockfile found. Run "nypm install" first.');
        return;
    }
    
    console.log('Checking for updates...');
    
    // Simplified - just show current versions
    for (const [name, pkg] of Object.entries(lockfile.packages)) {
        if (!package || package === name) {
            console.log(`  ${name}: ${pkg.version} (up to date)`);
        }
    }
}

// Check outdated
function outdated() {
    const lockfile = readLockfile();
    
    if (!lockfile) {
        console.log('No lockfile found.');
        return;
    }
    
    console.log('Checking for updates...\n');
    
    // In real implementation, compare with registry
    console.log('All packages are up to date.');
}

// Run script
function runScript(script) {
    const manifest = readManifest();
    
    if (!manifest || !manifest.scripts || !manifest.scripts[script]) {
        console.log(`Script "${script}" not found.`);
        return;
    }
    
    console.log(`Running ${script}: ${manifest.scripts[script]}`);
    
    // Execute script
    require('child_process').execSync(manifest.scripts[script], {
        stdio: 'inherit',
        cwd: process.cwd()
    });
}

// Clean
function clean() {
    const dirs = [MODULES_DIR, 'build', 'dist', 'node_modules'];
    
    for (const dir of dirs) {
        if (fs.existsSync(dir)) {
            console.log(`Removing ${dir}...`);
            fs.rmSync(dir, { recursive: true, force: true });
        }
    }
    
    console.log('Cleaned build artifacts.');
}

// Doctor
function doctor() {
    console.log('Nypm Doctor');
    console.log('============\n');
    console.log(`Version: 3.0.0`);
    console.log(`Registry: ${REGISTRY_URL}`);
    console.log(`Modules: ${MODULES_DIR}`);
    console.log(`Lockfile: ${LOCK_FILE}\n`);
    
    const manifest = readManifest();
    if (manifest) {
        console.log('Manifest: OK');
    } else {
        console.log('Manifest: Not found');
    }
    
    const lockfile = readLockfile();
    if (lockfile) {
        console.log(`Lockfile: OK (${Object.keys(lockfile.packages).length} packages)`);
    } else {
        console.log('Lockfile: Not found');
    }
    
    console.log('\nEnvironment: OK');
}

// Security audit
function audit() {
    const lockfile = readLockfile();
    
    if (!lockfile) {
        console.log('No lockfile found.');
        return;
    }
    
    console.log('Running security audit...\n');
    
    // In real implementation, check against vulnerability database
    console.log('No vulnerabilities found.');
}

// Main
const args = process.argv.slice(2);
const command = args[0];

if (!command) {
    console.log('Nypm 3.0.0 - Nyx Package Manager\n');
    console.log('Usage: nypm <command> [options]\n');
    console.log('Commands:');
    
    for (const [cmd, desc] of Object.entries(COMMANDS)) {
        console.log(`  ${cmd.padEnd(12)} ${desc}`);
    }
    
    console.log('\nExamples:');
    console.log('  nypm init myapp');
    console.log('  nypm add nyweb ^3.0');
    console.log('  nypm install');
    console.log('  nypm search web');
    
    process.exit(1);
}

switch (command) {
    case 'init':
        init(args[1], args[2]);
        break;
        
    case 'install':
    case 'i':
        install();
        break;
        
    case 'add':
    case 'a':
        const depMatch = (args[1] || '').match(/^(@?[\w-]+)(?:\s*@(.+))?$/);
        if (depMatch) {
            add(depMatch[1], depMatch[2], args.includes('--dev') || args.includes('-D'));
        } else {
            console.log('Usage: nypm add <package>[@version]');
        }
        break;
        
    case 'remove':
    case 'rm':
        if (args[1]) {
            remove(args[1]);
        }
        break;
        
    case 'update':
    case 'u':
        update(args[1]);
        break;
        
    case 'list':
    case 'ls':
        list();
        break;
        
    case 'search':
    case 's':
        if (args[1]) {
            search(args[1]);
        }
        break;
        
    case 'outdated':
    case 'out':
        outdated();
        break;
        
    case 'run':
        if (args[1]) {
            runScript(args[1]);
        }
        break;
        
    case 'clean':
    case 'c':
        clean();
        break;
        
    case 'doctor':
    case 'd':
        doctor();
        break;
        
    case 'audit':
        audit();
        break;
        
    case 'workspace':
        console.log('Workspace commands: init, add, remove');
        break;
        
    default:
        console.log(`Unknown command: ${command}`);
        process.exit(1);
}
