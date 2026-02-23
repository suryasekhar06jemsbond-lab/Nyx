# Changelog - Nyx Language VS Code Extension

All notable changes to this project will be documented in this file.

## [6.0.0] - 2026-02-24 - MAJOR RELEASE 🚀

### ✨ Complete Rebuild from Foundation
- Built extension from the ground up with modern architecture
- Migrated to latest VS Code API (v1.85.0+)
- Comprehensive TypeScript implementation
- Production-ready with enterprise features

### ✅ New Features

#### Commands & Execution
- ✨ `nyx.run` - Execute Nyx files (Ctrl+Shift+R)
- ✨ `nyx.build` - Compile projects (Ctrl+Shift+B)
- ✨ `nyx.format` - Format documents (Shift+Alt+F)
- ✨ `nyx.check` - Check for syntax errors
- ✨ `nyx.debug` - Start debugger (F5)
- ✨ `nyx.createProject` - Create new projects
- ✨ `nyx.showDocs` - Open documentation
- ✨ `nyx.installDependencies` - Install packages
- ✨ `nyx.updateExtension` - Auto-update

#### Language Features
- ✨ **Syntax Highlighting** - Complete TextMate grammar
- ✨ **Code Completion** - 50+ keywords, functions, snippets
- ✨ **Hover Information** - Context-aware documentation
- ✨ **Go to Definition** - Navigate to symbol definitions
- ✨ **Find References** - Find all usages of symbols
- ✨ **Rename Refactoring** - Safe symbol renaming
- ✨ **Document Symbols** - Quick navigation breadcrumbs
- ✨ **Signature Help** - Function parameter hints
- ✨ **Diagnostics** - Real-time error detection
- ✨ **Code Formatting** - Auto-format with smart indentation
- ✨ **Code Actions** - Quick fixes and suggestions

#### Code Snippets (50+ new)
- `fn` - Function definition
- `let`/`const` - Variable declarations
- `if`/`ifelse`/`while`/`for` - Control flow
- `class`/`trait` - Class and trait definitions
- `async`/`await` - Async operations
- `match` - Pattern matching
- `try`/`catch` - Exception handling
- `lambda` - Anonymous functions
- `array`/`hash` - Collection literals
- `import`/`use` - Module imports
- And 30+ more!

#### Configuration Options
- `nyx.runtime.path` - Custom runtime path
- `nyx.compiler.path` - Custom compiler path
- `nyx.formatter.enabled` - Enable/disable formatting
- `nyx.formatter.tabSize` - Indentation size (1-8)
- `nyx.formatter.useTabs` - Use tabs or spaces
- `nyx.linting.enabled` - Enable/disable linting
- `nyx.linting.level` - Lint severity level
- `nyx.diagnostics.onSave` - Diagnose on save
- `nyx.debugger.stopOnEntry` - Debug on entry
- `nyx.debugger.logLevel` - Debug log level
- `nyx.language.strictMode` - Strict type checking
- `nyx.language.inferTypes` - Type inference
- `nyx.hover.enabled` - Hover information
- `nyx.completion.enabled` - Code completion
- `nyx.completion.autoTrigger` - Auto-trigger completion
- `nyx.signature.enabled` - Signature help

#### Keyboard Shortcuts (Built-in)
- **Ctrl+Shift+R** (Cmd+Shift+R) - Run file
- **Ctrl+Shift+B** (Cmd+Shift+B) - Build project
- **Shift+Alt+F** (Shift+Option+F) - Format document
- **Ctrl+Shift+C** (Cmd+Shift+C) - Check file
- **F5** - Debug file

#### Context Menus
- Editor context menu integration
- Explorer context menu integration
- Command palette integration
- Quick access from multiple places

#### Color Themes
- 🎨 **Nyx Dark** - Professional dark theme
- 🎨 **Nyx Light** - Clean light theme
- Compatible with all VS Code themes

#### File Icons
- Custom icons for Nyx files (.ny)
- Language-specific icon theme support

### 🔧 Improvements
- **Performance** - Optimized for large projects
- **Reliability** - Better error handling
- **Stability** - Tested on Windows, macOS, Linux
- **Compatibility** - Works with VS Code 1.85.0+
- **Documentation** - Comprehensive README and examples
- **UX** - Improved UI and workflows

### 📚 Documentation
- Complete README with examples
- Inline code documentation
- Configuration guide
- Troubleshooting section
- Contributing guidelines

### 🐛 Bug Fixes
- Fixed syntax highlighting edge cases
- Improved error reporting
- Better file handling
- Fixed keybinding conflicts

### 🚀 Performance
- Faster code completion
- Reduced memory footprint
- Optimized diagnostics
- Parallel file processing

---

## [5.5.0] - 2025-12-15

### Added
- Basic Nyx language syntax highlighting
- Simple code snippets
- Icon theme support

### Fixed
- Windows compatibility issues

---

## [5.0.0] - 2025-10-01

### Added
- Initial VS Code extension release
- Basic language support

---

## Version History

| Version | Date | Status | Changes |
|---------|------|--------|---------|
| 6.0.0 | 2026-02-24 | ✅ Latest | Complete rewrite, 9 commands, 50+ features |
| 5.5.0 | 2025-12-15 | 📦 Stable | Basic language support |
| 5.0.0 | 2025-10-01 | 🔧 Archive | Initial release |

---

## Release Notes by Feature

### Language Support (6.0.0)
- Keywords: 40+ recognized
- Built-in functions: 30+ autocompleted
- Type annotations: Full support
- Operators: All Nyx operators
- Literals: Numbers, strings, collections

### Development Tools (6.0.0)
- Run Nyx programs directly from editor
- Build projects with compiler integration
- Format code automatically
- Check syntax in real-time
- Debug with breakpoints
- Manage dependencies

### Editor Features (6.0.0)
- Code completion with 50+ snippets
- Hover tooltips with documentation  
- Go to definition navigation
- Find all references
- Safe rename refactoring
- Document symbols/outline
- Breadcrumb navigation

### Project Management (6.0.0)
- Create new Nyx projects
- Install dependencies with nypm
- Run build tasks
- Manage workspace configuration

---

## Upgrade Guide

### From 5.5.0 to 6.0.0

**Breaking Changes:**
- None - fully backward compatible

**New Features to Explore:**
1. Try the new command palette commands (Ctrl+Shift+P)
2. Configure language settings in preferences
3. Use new code snippets (type `fn`, `class`, `if`, etc.)
4. Take advantage of code completion (Ctrl+Space)
5. Enable debugging (F5)

**Migration Steps:**
1. Update extension from marketplace
2. Reload VS Code (Ctrl+R / Cmd+R)  
3. No configuration needed - works out of the box
4. Existing .ny files work immediately

---

## Known Issues

### Current Release (6.0.0)
- None reported

### Previous Releases
- See GitHub issues for historical problems

---

## Future Roadmap

### Planned (6.1.0)
- [ ] Language Server Protocol (LSP) full implementation
- [ ] Advanced debugging features
- [ ] Performance profiler integration
- [ ] Test runner integration
- [ ] Package manager UI

### Proposed (7.0.0)
- [ ] AI-powered code suggestions
- [ ] Advanced refactoring tools
- [ ] Visual debugging interface
- [ ] Project templates
- [ ] Collaborative features

### Long-term Vision
- Full IDE-like experience in VS Code
- WebAssembly support
- Mobile development tools
- Game development features
- Data science tooling

---

## Contributing Changes

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

To report bugs or request features: [GitHub Issues](https://github.com/nyxlang/nyx-vscode-extension/issues)

---

## Thanks

Special thanks to:
- VS Code team for the excellent extension API
- Nyx language team for language specification
- Community contributors and bug reporters
- Everyone using and improving this extension

---

**Latest Update:** February 24, 2026
**Maintenance:** Active
**License:** MIT
