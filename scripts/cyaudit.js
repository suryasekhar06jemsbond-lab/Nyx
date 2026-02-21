#!/usr/bin/env node
// Nyx Vulnerability Database & Audit Tool

const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
let command = args[0] || 'help';
let target = args[1];

const VULN_DB_VERSION = '1.0';

// Known vulnerabilities database (embedded)
const KNOWN_VULNERABILITIES = [
    {
        id: 'CVE-2024-0001',
        package: 'stdlib',
        severity: 'LOW',
        description: 'Potential information disclosure in error messages',
        fixed_in: '4.0.1'
    },
    {
        id: 'CVE-2024-0002', 
        package: 'json',
        severity: 'MEDIUM',
        description: 'DoS via deeply nested JSON',
        fixed_in: '3.5.0'
    }
];

function showHelp() {
    console.log(`Nyx Vulnerability Database & Audit Tool

Usage:
    node cyaudit.js <command> [options]

Commands:
    audit <package>    Audit a package for vulnerabilities
    list              List known vulnerabilities
    check <version>   Check if version has known issues
    db-update         Update vulnerability database (placeholder)

Examples:
    node cyaudit.js audit ./mypackage
    node cyaudit.js list
    node cyaudit.js check 4.0.0`);
}

function auditPackage(packagePath) {
    console.log(`\nAuditing: ${packagePath}\n`);
    
    // Read package manifest
    const pkgFile = path.join(packagePath, 'ny.pkg');
    const pkgLock = path.join(packagePath, 'ny.lock');
    
    let packageName = path.basename(packagePath);
    let packageVersion = 'unknown';
    
    if (fs.existsSync(pkgFile)) {
        try {
            const content = fs.readFileSync(pkgFile, 'utf8');
            const match = content.match(/version:\s*["']?([^"'\n]+)/);
            if (match) {
                packageVersion = match[1];
            }
        } catch (e) {
            console.log('Note: Could not parse package version');
        }
    }
    
    console.log(`Package: ${packageName}`);
    console.log(`Version: ${packageVersion}`);
    
    // Check against known vulnerabilities
    console.log('\n--- Vulnerability Scan ---\n');
    
    const vulns = KNOWN_VULNERABILITIES.filter(v => v.package === packageName || v.package === '*');
    
    if (vulns.length === 0) {
        console.log('No known vulnerabilities found.'.green);
        console.log('\nNote: This does not guarantee the package is secure.');
        console.log('      Always review code and dependencies manually.');
        return;
    }
    
    let foundVulns = false;
    
    for (const vuln of vulns) {
        console.log(`[${vuln.severity}] ${vuln.id}`);
        console.log(`  Description: ${vuln.description}`);
        console.log(`  Fixed in: ${vuln.fixed_in}`);
        console.log('');
        
        // Check if version is affected
        if (packageVersion !== 'unknown' && vuln.fixed_in) {
            const current = parseVersion(packageVersion);
            const fixed = parseVersion(vuln.fixed_in);
            
            if (current && fixed && compareVersions(current, fixed) < 0) {
                console.log(`  Status: AFFECTED (your version: ${packageVersion})`.red.bold);
            } else {
                console.log(`  Status: PATCHED (your version: ${packageVersion})`.green);
            }
        }
        console.log('');
        
        foundVulns = true;
    }
    
    if (foundVulns) {
        console.log('\nRecommendation: Update to the latest version'.yellow);
    }
}

function listVulnerabilities() {
    console.log('\n=== Known Vulnerabilities ===\n');
    
    if (KNOWN_VULNERABILITIES.length === 0) {
        console.log('No vulnerabilities in database.');
        return;
    }
    
    for (const vuln of KNOWN_VULNERABILITIES) {
        const severityColor = vuln.severity === 'CRITICAL' ? 'red' 
            : vuln.severity === 'HIGH' ? 'orange'
            : vuln.severity === 'MEDIUM' ? 'yellow'
            : 'gray';
            
        console.log(`[${vuln.severity}] ${vuln.id}`);
        console.log(`  Package: ${vuln.package}`);
        console.log(`  Description: ${vuln.description}`);
        console.log(`  Fixed in: ${vuln.fixed_in || 'N/A'}`);
        console.log('');
    }
}

function checkVersion(version) {
    console.log(`\nChecking version: ${version}\n`);
    
    const vulns = KNOWN_VULNERABILITIES.filter(v => {
        if (!v.fixed_in) return false;
        const current = parseVersion(version);
        const fixed = parseVersion(v.fixed_in);
        return current && fixed && compareVersions(current, fixed) < 0;
    });
    
    if (vulns.length === 0) {
        console.log('No known issues with this version.'.green);
    } else {
        console.log(`Found ${vulns.length} issue(s):\n`.red);
        for (const vuln of vulns) {
            console.log(`- ${vuln.id}: ${vuln.description}`);
        }
    }
}

function parseVersion(v) {
    const match = v.match(/(\d+)\.(\d+)\.(\d+)/);
    if (!match) return null;
    return {
        major: parseInt(match[1]),
        minor: parseInt(match[2]),
        patch: parseInt(match[3])
    };
}

function compareVersions(a, b) {
    if (a.major !== b.major) return a.major - b.major;
    if (a.minor !== b.minor) return a.minor - b.minor;
    return a.patch - b.patch;
}

// Main
switch (command) {
    case 'audit':
        if (!target) {
            console.error('Error: Package path required');
            console.log('Usage: node cyaudit.js audit <package-path>');
            process.exit(1);
        }
        auditPackage(target);
        break;
        
    case 'list':
    case 'ls':
        listVulnerabilities();
        break;
        
    case 'check':
        if (!target) {
            console.error('Error: Version required');
            console.log('Usage: node cyaudit.js check <version>');
            process.exit(1);
        }
        checkVersion(target);
        break;
        
    case 'db-update':
        console.log('Vulnerability database update');
        console.log('In production, this would fetch from a remote CVE database.');
        console.log(`Current DB version: ${VULN_DB_VERSION}`);
        console.log(`Known vulnerabilities: ${KNOWN_VULNERABILITIES.length}`);
        break;
        
    default:
        showHelp();
}
