# NYX Language VS Code Extension

<p align="center">
  <img src="assets/nyx-logo.png" alt="NYX Logo" width="128" height="128"/>
</p>

<p align="center">
  <a href="https://marketplace.visualstudio.com/items?itemName=SuryaSekHarRoy.nyx-language">
    <img src="https://img.shields.io/visual-studio-marketplace/v/SuryaSekHarRoy.nyx-language?style=flat-square" alt="Version">
  </a>
  <a href="https://marketplace.visualstudio.com/items?itemName=SuryaSekHarRoy.nyx-language">
    <img src="https://img.shields.io/visual-studio-marketplace/i/SuryaSekHarRoy.nyx-language?style=flat-square" alt="Installs">
  </a>
  <a href="https://github.com/suryasekhar06jemsbond-lab/NYX-language/blob/main/editor/vscode/nyx-language/LICENSE.md">
    <img src="https://img.shields.io/github/license/suryasekhar06jemsbond-lab/NYX-language?style=flat-square" alt="License">
  </a>
</p>

---

## Download

### Latest Release (VSIX)
Download the latest VSIX extension file from GitHub Releases:

**[Download nyx-language.vsix](https://github.com/suryasekhar06jemsbond-lab/NYX-language/releases/latest/download/nyx-language.vsix)**

### Manual Installation
1. Download the `.vsix` file from the link above
2. Open VS Code
3. Go to Extensions view (`Ctrl+Shift+X` or `Cmd+Shift+X` on Mac)
4. Click the `...` menu in the top-right corner
5. Select "Install from VSIX..."
6. Choose---

## Features

 the downloaded file

- **Syntax Highlighting** - Full syntax highlighting for `.ny` and `.nx` files
- **IntelliSense** - Code completion and intelligent suggestions
- **Snippets** - Pre-built code snippets for common patterns
- **File Icons** - Custom file icons for NYX files
- **Debugging** - Debug support for NYX programs
- **Project Templates** - Quick start templates for new NYX projects

---

## Requirements

- VS Code version 1.85.0 or higher
- [NYX Runtime](https://github.com/suryasekhar06jemsbond-lab/NYX-language/releases) (optional, for running NYX code)

---

## Extension Settings

This extension contributes the following settings:

- `nyx.enable`: Enable/disable the NYX language server
- `nyx.trace.server`: Trace communication with the NYX language server

---

## Marketplace Installation

You can also install directly from the [VS Code Marketplace](https://marketplace.visualstudio.com/items?itemName=SuryaSekHarRoy.nyx-language).

---

## Building from Source

```bash
cd editor/vscode/nyx-language
npm install
npm run package
```

This will create a `.vsix` file in the `dist` folder.

---

## License

See [LICENSE.md](LICENSE.md) for details.

---

<p align="center">
  <sub>Built with ❤️ by the NYX Team</sub>
</p>
