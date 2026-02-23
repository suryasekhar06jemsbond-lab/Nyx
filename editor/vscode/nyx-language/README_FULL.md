# Nyx Language Support for VS Code

Professional language support for Nyx - A multi-paradigm, compiled programming language combining the expressiveness of Python with the performance of Rust.

![VS Code](https://img.shields.io/badge/VS%20Code-1.85.0+-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Version](https://img.shields.io/badge/version-6.0.0-brightgreen)

## Features

### 🎯 Core Language Features
- **Syntax Highlighting** - Full TextMate grammar for Nyx syntax
- **Code Completion** - IntelliSense with keywords, functions, and snippets
- **Hover Information** - Context-aware help on hover
- **Go to Definition** - Navigate to function and class definitions
- **Find References** - Find all usages of symbols
- **Rename Refactoring** - Rename symbols across the file
- **Document Symbols** - Quick navigation with breadcrumbs

### ⚡ Developer Tools
- **Run Nyx Files** - Execute .ny files directly (Ctrl+Shift+R / Cmd+Shift+R)
- **Build Project** - Compile projects with nyc compiler (Ctrl+Shift+B)
- **Format Code** - Automatic code formatting (Shift+Alt+F)
- **Diagnostics** - Real-time error and warning checking
- **Debugging** - Debug Nyx programs with breakpoints (F5)

### 📦 Project Management
- **Create Projects** - Generate new Nyx projects
- **Dependency Management** - Install packages with `nypm`
- **Build Tasks** - Integrated build workflows

### 📚 Language Features
- **50+ Code Snippets** - Common patterns and structures
- **3 Color Themes** - Dark, Light, and Nyx-specific themes
- **Smart Indentation** - Context-aware auto-indentation
- **Bracket Matching** - Automatic bracket and brace matching
- **Multi-line Comments** - Block comment support with nesting
- **Format Strings** - Support for interpolated strings

## Installation

### From VS Code Marketplace
1. Open VS Code
2. Go to Extensions (Ctrl+Shift+X / Cmd+Shift+X)
3. Search for "Nyx Language"
4. Click Install

### Manual Installation
```bash
git clone https://github.com/nyxlang/nyx-vscode-extension.git
cd nyx-vscode-extension/editor/vscode/nyx-language
npm install
npm run compile
vsce package
# Then install the .vsix file
```

## Quick Start

### Create a New Project
1. Press Ctrl+Shift+P (Cmd+Shift+P on Mac)
2. Select "Nyx: Create New Project"
3. Enter project name
4. Start coding!

### Run a File
1. Open a `.ny` file
2. Press Ctrl+Shift+R (Cmd+Shift+R)
3. Output appears in the integrated terminal

### Build a Project
1. Open the project folder
2. Press Ctrl+Shift+B (Cmd+Shift+B)  
3. Compiled output in `build/` directory

## Configuration

Access settings via: File → Preferences → Settings → Extensions → Nyx

### Runtime & Compiler
- `nyx.runtime.path` - Path to Nyx runtime (default: `nyx`)
- `nyx.compiler.path` - Path to Nyx compiler (default: `nyc`)

### Formatting
- `nyx.formatter.enabled` - Enable code formatting (default: true)
- `nyx.formatter.tabSize` - Indentation size (default: 4)
- `nyx.formatter.useTabs` - Use tabs instead of spaces (default: false)

### Analysis
- `nyx.linting.enabled` - Enable linting (default: true)
- `nyx.linting.level` - Minimum lint level: error/warning/info (default: warning)
- `nyx.diagnostics.onSave` - Run diagnostics on save (default: true)
- `nyx.language.strictMode` - Enable strict type checking (default: false)
- `nyx.language.inferTypes` - Enable type inference (default: true)

### Debugging
- `nyx.debugger.stopOnEntry` - Stop debugger on entry (default: false)
- `nyx.debugger.logLevel` - Debugger log level (default: info)

### Language Server Features
- `nyx.hover.enabled` - Enable hover information (default: true)
- `nyx.completion.enabled` - Enable code completion (default: true)
- `nyx.completion.autoTrigger` - Auto trigger completion (default: true)
- `nyx.signature.enabled` - Enable signature help (default: true)

## Keyboard Shortcuts

| Command | Windows/Linux | macOS | Description |
|---------|--------------|-------|-------------|
| Run File | Ctrl+Shift+R | Cmd+Shift+R | Execute current Nyx file |
| Build | Ctrl+Shift+B | Cmd+Shift+B | Build the project |
| Format | Shift+Alt+F | Shift+Option+F | Format current document |
| Debug | F5 | F5 | Start debugger |
| Check | Ctrl+Shift+C | Cmd+Shift+C | Check file for errors |

## Commands (Ctrl+Shift+P / Cmd+Shift+P)

### Execution
- `Nyx: Run File` - Run current Nyx file
- `Nyx: Build Project` - Build the project
- `Nyx: Check File` - Check file for syntax errors
- `Nyx: Debug File` - Debug current file

### Project Management
- `Nyx: Create New Project` - Create new Nyx project
- `Nyx: Install Dependencies` - Install with nypm
- `Nyx: Open Documentation` - Open official docs
- `Nyx: Update Extension` - Update to latest version

### Editor
- `Nyx: Format Document` - Format current document

## Code Snippets

Quick snippets available while typing:

- `fn` - Function definition
- `let` / `var` - Variable declaration
- `const` - Constant declaration
- `if` / `ifelse` - If/Else statements
- `while` - While loop
- `for` / `forin` - For loops
- `class` - Class definition
- `trait` - Trait definition
- `match` - Match expression
- `try` - Try-catch block
- `async` / `await` - Async operations
- `print` / `println` - Output functions
- `import` / `use` - Module imports
- `lambda` - Anonymous functions
- `array` / `hash` - Collection literals

## Themes

Select from built-in color themes:
- **Nyx Dark** - Professional dark theme optimized for Nyx
- **Nyx Light** - Clean light theme with good contrast
- **Default VS Code Themes** - Compatible with all VS Code themes

### Customizing Colors

Create custom color overrides in `settings.json`:

```json
"editor.tokenColorCustomizations": {
  "[Nyx Dark]": {
    "textMateRules": [
      {
        "scope": "keyword.nyx",
        "settings": {
          "foreground": "#FF6B6B"
        }
      }
    ]
  }
}
```

## Example Programs

### Hello World
```nyx
fn main() {
    print("Hello, Nyx!")
}

main()
```

### Functions & Types
```nyx
fn add(a: Int, b: Int) -> Int {
    return a + b
}

let result = add(5, 3)
print(result)
```

### Classes
```nyx
class Person {
    pub let name: String
    pub let age: Int

    pub fn new(name: String, age: Int) -> Self {
        return Self { name: name, age: age }
    }

    pub fn greet(self) {
        print("Hello, I'm " + self.name)
    }
}

let person = new Person("Alice", 30)
person.greet()
```

### Pattern Matching
```nyx
let value = 42

match value {
    0 => print("Zero"),
    1..100 => print("Small"),
    _ => print("Large")
}
```

### Collections & Iteration
```nyx
let numbers = [1, 2, 3, 4, 5]
let doubled = numbers.map(fn(x) { x * 2 })
print(doubled)

let person = {"name": "Bob", "age": 25}
print(person["name"])
```

## Troubleshooting

### Extension not activating
1. Ensure VS Code version ≥ 1.85.0
2. Check `Help → About` for version
3. Reload VS Code window (Ctrl+R / Cmd+R)

### Syntax highlighting not working
1. Verify file extension is `.ny`
2. Check language is set to "Nyx" (bottom right corner)
3. Reload syntax highlighting: `Developer: Reload Window`

### Runtime not found
1. Ensure Nyx is installed: `nyx --version`
2. Update `nyx.runtime.path` setting to correct path
3. Add Nyx to system PATH

### Formatting issues
1. Check `nyx.formatter.enabled` is true
2. Verify tab size setting matches your preference
3. Try reformatting: Shift+Alt+F

## Performance Tips

- Disable linting for large files: `nyx.linting.enabled: false`
- Use incremental compilation: Set `nyx.compiler.path` to compiler with `--incremental`
- Cache projects: nypm automatically caches dependencies
- Enable only needed language features in settings

## Contributing

Contributions welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md)

### Building from Source
```bash
git clone https://github.com/nyxlang/nyx-vscode-extension.git
cd nyx-vscode-extension/editor/vscode/nyx-language
npm install
npm run compile
npm run watch  # For development mode
```

### Running Tests
```bash
npm test
```

### Packaging
```bash
npm run package
```

## Changelog

### 6.0.0 (Latest)
- Complete rewrite from foundation
- Full command integration
- Enhanced IntelliSense
- Improved diagnostics
- Better formatting support
- Comprehensive keybindings
- New themes and icons
- Performance optimizations

[See full CHANGELOG.md](CHANGELOG.md)

## Related Extensions

- **Nyx Debugger** - Advanced debugging capabilities
- **Nyx Language Server** - Full LSP support
- **Nyx Package Manager** - nypm integration
- **Nyx Themes** - Additional color schemes

## Resources

- [Official Nyx Website](https://nyxlang.dev)
- [Language Documentation](https://nyxlang.dev/docs)
- [GitHub Repository](https://github.com/nyxlang/nyx)
- [Issue Tracker](https://github.com/nyxlang/nyx-vscode-extension/issues)
- [Discussions](https://github.com/nyxlang/nyx/discussions)

## License

MIT - See [LICENSE.md](LICENSE.md)

## Support

For help and support:
- 📧 Email: support@nyxlang.dev
- 💬 Discord: [Nyx Community](https://discord.gg/nyxlang)
- 🐛 Issues: [GitHub Issues](https://github.com/nyxlang/nyx-vscode-extension/issues)
- 📚 Wiki: [Community Wiki](https://github.com/nyxlang/nyx/wiki)

---

**Made with ❤️ for the Nyx community**

![Nyx Logo](nyx-logo.png)
