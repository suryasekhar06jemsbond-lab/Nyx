// Nyx Language Support - Web Extension Entry Point
// Browser-compatible: no Node.js APIs (no fs, child_process, os, path)
// Provides: syntax highlighting (via grammar), snippets, completion, hover, symbols, diagnostics, formatting

const vscode = require('vscode');

const NYX_MODE = { language: 'nyx' };

// --- Keyword & Builtin Data ---

const NYX_KEYWORDS = [
    'var', 'let', 'const', 'if', 'else', 'elif', 'for', 'while', 'do',
    'function', 'fn', 'class', 'struct', 'enum', 'trait', 'impl',
    'return', 'break', 'continue', 'yield', 'await', 'async',
    'import', 'use', 'from', 'export', 'module', 'package',
    'match', 'switch', 'case', 'default', 'try', 'catch', 'finally', 'throw',
    'new', 'delete', 'typeof', 'instanceof', 'in', 'of', 'as', 'is',
    'true', 'false', 'null', 'nil', 'none', 'self', 'this', 'super',
    'pub', 'priv', 'static', 'abstract', 'final', 'override', 'virtual',
    'mut', 'ref', 'type', 'interface', 'extends', 'implements',
    'and', 'or', 'not', 'print', 'println', 'input', 'assert'
];

const NYX_BUILTINS = {
    'print':     { sig: 'print(...args: any)', doc: 'Prints values to stdout.' },
    'println':   { sig: 'println(...args: any)', doc: 'Prints values to stdout with newline.' },
    'input':     { sig: 'input(prompt?: string): string', doc: 'Reads a line from stdin.' },
    'len':       { sig: 'len(collection: any): int', doc: 'Returns the length of a collection.' },
    'type':      { sig: 'type(value: any): string', doc: 'Returns the type name of a value.' },
    'int':       { sig: 'int(value: any): int', doc: 'Converts a value to integer.' },
    'float':     { sig: 'float(value: any): float', doc: 'Converts a value to float.' },
    'str':       { sig: 'str(value: any): string', doc: 'Converts a value to string.' },
    'bool':      { sig: 'bool(value: any): bool', doc: 'Converts a value to boolean.' },
    'range':     { sig: 'range(start: int, end: int, step?: int): Range', doc: 'Creates an integer range.' },
    'abs':       { sig: 'abs(n: number): number', doc: 'Returns absolute value.' },
    'min':       { sig: 'min(...args: number): number', doc: 'Returns the minimum value.' },
    'max':       { sig: 'max(...args: number): number', doc: 'Returns the maximum value.' },
    'assert':    { sig: 'assert(condition: bool, msg?: string)', doc: 'Asserts a condition is true.' },
    'exit':      { sig: 'exit(code?: int)', doc: 'Exits the program with an optional code.' }
};

const NYX_MODULES = [
    'math', 'io', 'fs', 'net', 'http', 'json', 'csv', 'regex',
    'crypto', 'hash', 'time', 'date', 'os', 'sys', 'process',
    'collections', 'itertools', 'functools', 'string', 'color',
    'testing', 'logging', 'threading', 'async', 'socket', 'db'
];

// --- Activate ---

function activate(context) {
    console.log('Nyx Language Support v6.0.1 (Web) activated');

    // Register commands (web-safe: show info messages instead of running terminals)
    const webCommands = [
        ['nyx.run',        'Run is not available in web mode. Use a desktop VS Code to run Nyx files.'],
        ['nyx.build',      'Build is not available in web mode. Use a desktop VS Code to build Nyx projects.'],
        ['nyx.format',     null], // handled by formatting provider
        ['nyx.check',      null], // handled by diagnostics
        ['nyx.debug',      'Debug is not available in web mode. Use a desktop VS Code to debug Nyx files.'],
        ['nyx.createProject', 'Create Project is not available in web mode.'],
        ['nyx.installDependencies', 'Package management is not available in web mode.'],
        ['nyx.updateExtension', null]
    ];

    for (const [cmd, msg] of webCommands) {
        if (msg) {
            context.subscriptions.push(vscode.commands.registerCommand(cmd, () => {
                vscode.window.showInformationMessage(msg);
            }));
        }
    }

    // nyx.format - use the formatting provider
    context.subscriptions.push(vscode.commands.registerCommand('nyx.format', async () => {
        const editor = vscode.window.activeTextEditor;
        if (editor && editor.document.languageId === 'nyx') {
            await vscode.commands.executeCommand('editor.action.formatDocument');
        }
    }));

    // nyx.check - trigger diagnostics refresh
    context.subscriptions.push(vscode.commands.registerCommand('nyx.check', () => {
        const editor = vscode.window.activeTextEditor;
        if (editor && editor.document.languageId === 'nyx') {
            refreshDiagnostics(editor.document, diagnosticCollection);
            vscode.window.showInformationMessage('Nyx: Check complete');
        }
    }));

    // nyx.showDocs
    context.subscriptions.push(vscode.commands.registerCommand('nyx.showDocs', async () => {
        const docs = [
            { label: 'Language Specification', url: 'https://github.com/suryasekhar06jemsbond-lab/Nyx/blob/main/docs/LANGUAGE_SPEC.md' },
            { label: 'Getting Started', url: 'https://github.com/suryasekhar06jemsbond-lab/Nyx/blob/main/docs/BOOTSTRAP.md' },
            { label: 'Examples', url: 'https://github.com/suryasekhar06jemsbond-lab/Nyx/tree/main/examples' },
            { label: 'API Reference', url: 'https://github.com/suryasekhar06jemsbond-lab/Nyx/blob/main/docs/ARCHITECTURE.md' },
            { label: 'GitHub Repository', url: 'https://github.com/suryasekhar06jemsbond-lab/Nyx' }
        ];
        const selected = await vscode.window.showQuickPick(docs, { placeHolder: 'Select documentation to open' });
        if (selected) {
            vscode.env.openExternal(vscode.Uri.parse(selected.url));
        }
    }));

    // nyx.updateExtension
    context.subscriptions.push(vscode.commands.registerCommand('nyx.updateExtension', () => {
        vscode.window.showInformationMessage(
            'Nyx Programming Language v6.0.1 - Check Extensions for updates',
            'Open Extensions'
        ).then(selection => {
            if (selection === 'Open Extensions') {
                vscode.commands.executeCommand('workbench.extensions.action.showExtensionsWithIds', ['SuryaSekharRoy.nyx-language']);
            }
        });
    }));

    // --- Language Providers ---

    // Hover
    context.subscriptions.push(vscode.languages.registerHoverProvider(NYX_MODE, {
        provideHover(document, position) {
            const range = document.getWordRangeAtPosition(position);
            if (!range) return null;
            const word = document.getText(range);

            if (NYX_BUILTINS[word]) {
                const b = NYX_BUILTINS[word];
                return new vscode.Hover(new vscode.MarkdownString(`**${word}**\n\n\`${b.sig}\`\n\n${b.doc}`));
            }

            if (NYX_KEYWORDS.includes(word)) {
                return new vscode.Hover(new vscode.MarkdownString(`**${word}** — Nyx keyword`));
            }

            if (NYX_MODULES.includes(word)) {
                return new vscode.Hover(new vscode.MarkdownString(`**${word}** — Nyx standard library module`));
            }

            return null;
        }
    }));

    // Completion
    context.subscriptions.push(vscode.languages.registerCompletionItemProvider(NYX_MODE, {
        provideCompletionItems(document, position) {
            const completions = [];

            // Keywords
            for (const kw of NYX_KEYWORDS) {
                const item = new vscode.CompletionItem(kw, vscode.CompletionItemKind.Keyword);
                completions.push(item);
            }

            // Builtins
            for (const [name, info] of Object.entries(NYX_BUILTINS)) {
                const item = new vscode.CompletionItem(name, vscode.CompletionItemKind.Function);
                item.detail = info.sig;
                item.documentation = info.doc;
                completions.push(item);
            }

            // Modules
            for (const mod of NYX_MODULES) {
                const item = new vscode.CompletionItem(mod, vscode.CompletionItemKind.Module);
                item.detail = `Nyx module: ${mod}`;
                completions.push(item);
            }

            // Snippets
            const funcSnippet = new vscode.CompletionItem('function', vscode.CompletionItemKind.Snippet);
            funcSnippet.insertText = new vscode.SnippetString('function ${1:name}(${2:args}) {\n\t$0\n}');
            funcSnippet.detail = 'Function definition';
            completions.push(funcSnippet);

            const classSnippet = new vscode.CompletionItem('class', vscode.CompletionItemKind.Snippet);
            classSnippet.insertText = new vscode.SnippetString('class ${1:Name} {\n\t$0\n}');
            classSnippet.detail = 'Class definition';
            completions.push(classSnippet);

            const ifSnippet = new vscode.CompletionItem('if', vscode.CompletionItemKind.Snippet);
            ifSnippet.insertText = new vscode.SnippetString('if (${1:condition}) {\n\t$0\n}');
            ifSnippet.detail = 'If statement';
            completions.push(ifSnippet);

            const forSnippet = new vscode.CompletionItem('for', vscode.CompletionItemKind.Snippet);
            forSnippet.insertText = new vscode.SnippetString('for (${1:item} in ${2:collection}) {\n\t$0\n}');
            forSnippet.detail = 'For loop';
            completions.push(forSnippet);

            const matchSnippet = new vscode.CompletionItem('match', vscode.CompletionItemKind.Snippet);
            matchSnippet.insertText = new vscode.SnippetString('match (${1:value}) {\n\t${2:pattern} => ${3:result},\n\t_ => ${0:default}\n}');
            matchSnippet.detail = 'Match expression';
            completions.push(matchSnippet);

            return completions;
        }
    }, '.', ' '));

    // Document Symbols
    context.subscriptions.push(vscode.languages.registerDocumentSymbolProvider(NYX_MODE, {
        provideDocumentSymbols(document) {
            const symbols = [];
            const text = document.getText();

            const patterns = [
                { regex: /function\s+([a-zA-Z_]\w*)/g, kind: vscode.SymbolKind.Function, label: 'Function' },
                { regex: /fn\s+([a-zA-Z_]\w*)/g, kind: vscode.SymbolKind.Function, label: 'Function' },
                { regex: /class\s+([a-zA-Z_]\w*)/g, kind: vscode.SymbolKind.Class, label: 'Class' },
                { regex: /struct\s+([a-zA-Z_]\w*)/g, kind: vscode.SymbolKind.Struct, label: 'Struct' },
                { regex: /enum\s+([a-zA-Z_]\w*)/g, kind: vscode.SymbolKind.Enum, label: 'Enum' },
                { regex: /trait\s+([a-zA-Z_]\w*)/g, kind: vscode.SymbolKind.Interface, label: 'Trait' },
                { regex: /(?:let|var|const)\s+([a-zA-Z_]\w*)/g, kind: vscode.SymbolKind.Variable, label: 'Variable' }
            ];

            for (const p of patterns) {
                let match;
                while ((match = p.regex.exec(text))) {
                    const line = document.positionAt(match.index).line;
                    const range = new vscode.Range(line, 0, line, match[0].length);
                    symbols.push(new vscode.DocumentSymbol(match[1], p.label, p.kind, range, range));
                }
            }

            return symbols;
        }
    }));

    // Definition (same-file)
    context.subscriptions.push(vscode.languages.registerDefinitionProvider(NYX_MODE, {
        provideDefinition(document, position) {
            const wordRange = document.getWordRangeAtPosition(position);
            if (!wordRange) return null;
            const word = document.getText(wordRange);
            const text = document.getText();

            const regex = new RegExp(`(?:function|fn|class|struct|enum|trait|var|let|const)\\s+${word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`);
            const match = regex.exec(text);

            if (match) {
                const targetPos = document.positionAt(match.index);
                return new vscode.Location(document.uri, targetPos);
            }
            return null;
        }
    }));

    // References
    context.subscriptions.push(vscode.languages.registerReferenceProvider(NYX_MODE, {
        provideReferences(document, position) {
            const range = document.getWordRangeAtPosition(position);
            if (!range) return [];
            const word = document.getText(range);
            const references = [];
            const text = document.getText();
            const escapedWord = word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
            const regex = new RegExp(`\\b${escapedWord}\\b`, 'g');

            let match;
            while ((match = regex.exec(text))) {
                const startPos = document.positionAt(match.index);
                const endPos = document.positionAt(match.index + word.length);
                references.push(new vscode.Location(document.uri, new vscode.Range(startPos, endPos)));
            }
            return references;
        }
    }));

    // Rename
    context.subscriptions.push(vscode.languages.registerRenameProvider(NYX_MODE, {
        provideRenameEdits(document, position, newName) {
            const range = document.getWordRangeAtPosition(position);
            if (!range) return null;
            const word = document.getText(range);
            const edit = new vscode.WorkspaceEdit();
            const text = document.getText();
            const escapedWord = word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
            const regex = new RegExp(`\\b${escapedWord}\\b`, 'g');

            let match;
            while ((match = regex.exec(text))) {
                const startPos = document.positionAt(match.index);
                const endPos = document.positionAt(match.index + word.length);
                edit.replace(document.uri, new vscode.Range(startPos, endPos), newName);
            }
            return edit;
        }
    }));

    // Formatting
    context.subscriptions.push(vscode.languages.registerDocumentFormattingEditProvider(NYX_MODE, {
        provideDocumentFormattingEdits(document) {
            const edits = [];
            for (let i = 0; i < document.lineCount; i++) {
                const line = document.lineAt(i);
                const trimmed = line.text.trimEnd();
                if (trimmed.length < line.text.length) {
                    edits.push(vscode.TextEdit.delete(new vscode.Range(i, trimmed.length, i, line.text.length)));
                }
            }
            return edits;
        }
    }));

    // Signature Help
    context.subscriptions.push(vscode.languages.registerSignatureHelpProvider(NYX_MODE, {
        provideSignatureHelp(document, position) {
            const line = document.lineAt(position).text;
            const prefix = line.substring(0, position.character);

            for (const [name, info] of Object.entries(NYX_BUILTINS)) {
                if (prefix.trimEnd().endsWith(name + '(')) {
                    const signature = new vscode.SignatureInformation(info.sig, info.doc);
                    const help = new vscode.SignatureHelp();
                    help.signatures = [signature];
                    help.activeSignature = 0;
                    help.activeParameter = 0;
                    return help;
                }
            }
            return null;
        }
    }, '(', ','));

    // Code Actions
    context.subscriptions.push(vscode.languages.registerCodeActionsProvider(NYX_MODE, {
        provideCodeActions(document, range, ctx) {
            const actions = [];
            for (const diag of ctx.diagnostics) {
                if (diag.message.includes("'var'")) {
                    const action = new vscode.CodeAction("Replace 'var' with 'let'", vscode.CodeActionKind.QuickFix);
                    action.edit = new vscode.WorkspaceEdit();
                    action.edit.replace(document.uri, diag.range, 'let');
                    action.diagnostics = [diag];
                    actions.push(action);
                }
            }
            return actions;
        }
    }));

    // Semantic Tokens
    const tokenTypes = ['class', 'function', 'variable', 'parameter'];
    const tokenModifiers = ['declaration', 'readonly'];
    const legend = new vscode.SemanticTokensLegend(tokenTypes, tokenModifiers);

    context.subscriptions.push(vscode.languages.registerDocumentSemanticTokensProvider(NYX_MODE, {
        provideDocumentSemanticTokens(document) {
            const builder = new vscode.SemanticTokensBuilder(legend);
            const text = document.getText();

            const classRegex = /class\s+([a-zA-Z_]\w*)/g;
            let match;
            while ((match = classRegex.exec(text))) {
                const pos = document.positionAt(match.index + match[0].indexOf(match[1]));
                builder.push(pos.line, pos.character, match[1].length, 0, 1);
            }

            const funcRegex = /(?:function|fn)\s+([a-zA-Z_]\w*)/g;
            while ((match = funcRegex.exec(text))) {
                const pos = document.positionAt(match.index + match[0].indexOf(match[1]));
                builder.push(pos.line, pos.character, match[1].length, 1, 1);
            }

            return builder.build();
        }
    }, legend));

    // --- Diagnostics ---
    const diagnosticCollection = vscode.languages.createDiagnosticCollection('nyx');
    context.subscriptions.push(diagnosticCollection);

    if (vscode.window.activeTextEditor) {
        refreshDiagnostics(vscode.window.activeTextEditor.document, diagnosticCollection);
    }

    context.subscriptions.push(
        vscode.window.onDidChangeActiveTextEditor(editor => {
            if (editor) refreshDiagnostics(editor.document, diagnosticCollection);
        })
    );
    context.subscriptions.push(
        vscode.workspace.onDidChangeTextDocument(e => refreshDiagnostics(e.document, diagnosticCollection))
    );
    context.subscriptions.push(
        vscode.workspace.onDidCloseTextDocument(doc => diagnosticCollection.delete(doc.uri))
    );

    console.log('Nyx web extension: all providers registered');
}

function refreshDiagnostics(doc, collection) {
    if (doc.languageId !== 'nyx') return;

    const diagnostics = [];
    const config = vscode.workspace.getConfiguration('nyx');
    const lintingEnabled = config.get('linting.enabled');
    const mode = config.get('analysis.typeCheckingMode');

    if (mode === 'off' || lintingEnabled === false) {
        collection.clear();
        return;
    }

    for (let i = 0; i < doc.lineCount; i++) {
        const line = doc.lineAt(i);
        const trimmed = line.text.trim();

        if (trimmed.length > 0 &&
            !trimmed.endsWith(';') &&
            !trimmed.endsWith('{') &&
            !trimmed.endsWith('}') &&
            !trimmed.endsWith('(') &&
            !trimmed.endsWith(',') &&
            !trimmed.startsWith('//') &&
            !trimmed.startsWith('#') &&
            !trimmed.startsWith('*') &&
            !trimmed.startsWith('import') &&
            !trimmed.startsWith('use')) {
            diagnostics.push(new vscode.Diagnostic(
                new vscode.Range(i, 0, i, line.text.length),
                'Missing semicolon',
                vscode.DiagnosticSeverity.Warning
            ));
        }

        if (mode === 'strict' && line.text.includes('var ')) {
            const idx = line.text.indexOf('var ');
            diagnostics.push(new vscode.Diagnostic(
                new vscode.Range(i, idx, i, idx + 3),
                "Use 'let' or 'const' instead of 'var' in strict mode.",
                vscode.DiagnosticSeverity.Error
            ));
        }
    }

    collection.set(doc.uri, diagnostics);
}

function deactivate() {
    console.log('Nyx web extension deactivated');
}

module.exports = { activate, deactivate };
