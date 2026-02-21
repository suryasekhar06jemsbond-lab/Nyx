const fs = require('fs');
const path = require('path');

const enginesDir = path.join(__dirname, '..', '..', 'engines');

const engines = fs.readdirSync(enginesDir, { withFileTypes: true })
    .filter(dirent => dirent.isDirectory() && dirent.name !== 'nypm')
    .map(dirent => dirent.name);

engines.forEach(engine => {
    try {
        const enginePath = path.join(enginesDir, engine);
        // Assuming the main file is index.js, or the directory itself is a module
        module.exports[engine] = require(enginePath);
    } catch (e) {
        console.error(`Failed to load engine: ${engine}`, e);
    }
});
