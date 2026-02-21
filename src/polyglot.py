#!/usr/bin/env python3
"""Universal Polyglot Code Runner."""

import os, re, sys, subprocess, tempfile, shutil, webbrowser
from typing import Tuple, Any, List
from enum import Enum


class Language(Enum):
    NYX = "nyx"
    PYTHON = "python"
    JAVASCRIPT = "javascript"
    TYPESCRIPT = "typescript"
    RUBY = "ruby"
    PHP = "php"
    PERL = "perl"
    LUA = "lua"
    R = "r"
    JULIA = "julia"
    HASKELL = "haskell"
    C = "c"
    CPP = "cpp"
    RUST = "rust"
    GO = "go"
    SWIFT = "swift"
    JAVA = "java"
    KOTLIN = "kotlin"
    BASH = "bash"
    POWERSHELL = "powershell"
    HTML = "html"
    CSS = "css"
    JSON = "json"
    YAML = "yaml"
    SQL = "sql"
    UNKNOWN = "unknown"


class PolyglotRunner:
    def __init__(self):
        self.temp_dir = None
        self._nyx_only_checks = (
            (re.compile(r"^\s*<<<"), "polyglot block start marker '<<<'"),
            (re.compile(r"^\s*>>>"), "polyglot block end marker '>>>'"),
            (re.compile(r"^\s*#!.*\b(python|node|ruby|php|perl|bash|sh|pwsh|powershell)\b", re.IGNORECASE), "foreign shebang"),
            (re.compile(r"^\s*def\s+[A-Za-z_]\w*\s*\("), "Python-style 'def' declaration"),
            (re.compile(r"^\s*from\s+[A-Za-z_][\w.]*\s+import\b"), "Python-style import statement"),
            (re.compile(r"^\s*import\s+[A-Za-z_][\w.]*\s*$"), "Python-style bare import"),
            (re.compile(r"\bconsole\.log\s*\("), "JavaScript console API"),
            (re.compile(r"\brequire\s*\("), "JavaScript require()"),
            (re.compile(r"^\s*function\s+[A-Za-z_]\w*\s*\("), "JavaScript-style function declaration"),
        )
        
    def __del__(self):
        if self.temp_dir and os.path.exists(self.temp_dir):
            shutil.rmtree(self.temp_dir)
    
    def _get_temp_dir(self):
        if self.temp_dir is None:
            self.temp_dir = tempfile.mkdtemp(prefix="nyx_")
        return self.temp_dir
    
    def _is_python_line(self, line):
        line = line.strip()
        if not line or line.startswith('#'):
            return False
        # Python-specific patterns that Nyx doesn't use
        if 'import ' in line or 'from ' in line:
            return True
        # def is Python-specific (Nyx uses fn)
        if line.startswith('def ') or ' def ' in line:
            return True
        # class is shared but check for Python-style
        if line.startswith('class ') and '(' not in line:
            return True
        # print with parentheses is Python (Nyx also uses print)
        # So we check for more specific patterns
        if 'print(' in line and 'print(' not in line.replace('print(', ''):
            # Check if it's not Nyx-style print
            if 'fmt.print' not in line and 'io.print' not in line:
                return True
        # Self is Python-style (Nyx uses self too, but let's be careful)
        # Python-specific keywords
        if 'elif ' in line or 'self.__' in line:
            return True
        return False
    
    def _is_javascript_line(self, line):
        line = line.strip()
        if not line:
            return False
        if 'console.log' in line or 'document.' in line or 'require(' in line:
            return True
        if 'const ' in line or 'let ' in line or 'var ' in line:
            return True
        if 'function ' in line or '=>' in line:
            return True
        if 'async function' in line or 'await ' in line:
            return True
        return False
    
    def _is_nyx_line(self, line):
        line = line.strip()
        if not line:
            return False
        # Nyx-specific: fn keyword (Python uses def)
        if 'fn ' in line and 'def ' not in line:
            return True
        # Nyx uses -> for return type (like Rust/TypeScript)
        if '->' in line and '=>' not in line:
            return True
        # Nyx module declaration
        if line.startswith('module ') and '{' in line:
            return True
        return False
    
    def _is_ruby_line(self, line):
        line = line.strip()
        if not line:
            return False
        if 'puts ' in line or 'gets ' in line:
            return True
        if 'def ' in line and 'self.' in line:
            return True
        if 'end' == line or line.startswith('end '):
            return True
        if 'puts' in line or 'gets' in line:
            return True
        return False
    
    def _split_into_blocks(self, source):
        lines = source.split('\n')
        blocks = []
        current_block = []
        current_lang = None
        
        for line in lines:
            stripped = line.strip()
            if not stripped or stripped.startswith('#') or stripped.startswith('//'):
                current_block.append(line)
                continue
            
            line_lang = Language.UNKNOWN
            if self._is_python_line(line):
                line_lang = Language.PYTHON
            elif self._is_javascript_line(line):
                line_lang = Language.JAVASCRIPT
            elif self._is_nyx_line(line):
                line_lang = Language.NYX
            
            if current_lang is None:
                current_lang = line_lang if line_lang != Language.UNKNOWN else Language.PYTHON
                current_block.append(line)
            elif line_lang != current_lang and line_lang != Language.UNKNOWN:
                if current_block:
                    block_text = '\n'.join(current_block)
                    blocks.append((block_text, current_lang))
                current_lang = line_lang
                current_block = [line]
            else:
                current_block.append(line)
        
        if current_block:
            block_text = '\n'.join(current_block)
            blocks.append((block_text, current_lang))
        
        return blocks

    def detect_language(self, source, filename=''):
        lines = source.strip().split('\n')
        if lines:
            first = lines[0].strip().lower()
            if first.startswith('#!'):
                if 'python' in first: return Language.PYTHON
                if 'node' in first: return Language.JAVASCRIPT
                if 'ruby' in first: return Language.RUBY
                if 'bash' in first: return Language.BASH
        
        if '<<<' in source and '>>>' in source:
            return Language.UNKNOWN
        
        source_lower = source.lower()
        
        if 'import ' in source or 'def ' in source or ('print(' in source and 'fn ' not in source):
            return Language.PYTHON
        
        if 'console.log' in source or 'function ' in source or '=>' in source:
            return Language.JAVASCRIPT
        
        if ('fn ' in source or '->' in source) and 'def ' not in source:
            return Language.NYX
        
        if '<html' in source_lower or '<!doctype' in source_lower:
            return Language.HTML
        
        if '{' in source and ':' in source and ';' in source:
            return Language.CSS
        
        try:
            import json
            json.loads(source)
            return Language.JSON
        except: pass
        
        if 'select ' in source_lower and ' from ' in source_lower:
            return Language.SQL
        
        # Trust file extension for language detection when provided
        if filename:
            ext = os.path.splitext(filename)[1].lower()
            if ext in ('.ny', '.nyx'):
                # Always treat .ny/.nyx files as Nyx sources
                return Language.NYX
            
            ext_map = {
                '.py': Language.PYTHON, '.js': Language.JAVASCRIPT,
                '.ts': Language.TYPESCRIPT, '.rb': Language.RUBY,
                '.php': Language.PHP, '.pl': Language.PERL,
                '.lua': Language.LUA, '.r': Language.R,
                '.jl': Language.JULIA, '.hs': Language.HASKELL,
                '.c': Language.C, '.cpp': Language.CPP,
                '.rs': Language.RUST, '.go': Language.GO,
                '.swift': Language.SWIFT, '.java': Language.JAVA,
                '.kt': Language.KOTLIN, '.sh': Language.BASH,
                '.ps1': Language.POWERSHELL, '.html': Language.HTML,
                '.css': Language.CSS, '.json': Language.JSON,
                '.yaml': Language.YAML, '.yml': Language.YAML,
                '.sql': Language.SQL, '.ny': Language.NYX, '.nyx': Language.NYX,
            }
            if ext in ext_map:
                return ext_map[ext]
        
        return Language.PYTHON

    def _validate_nyx_only_source(self, source, filename=''):
        display = filename if filename else "<memory>"
        for line_no, raw in enumerate(source.split('\n'), start=1):
            stripped = raw.strip()
            if not stripped or stripped.startswith('#') or stripped.startswith('//'):
                continue
            for pattern, reason in self._nyx_only_checks:
                if pattern.search(raw):
                    return False, f"{display}:{line_no}: .ny files are NYX-only; found {reason}."
        return True, None

    def run(self, source, language=None, filename=''):
        ext = os.path.splitext(filename)[1].lower() if filename else ""
        if ext in ('.ny', '.nyx'):
            ok, error = self._validate_nyx_only_source(source, filename)
            if not ok:
                return False, None, error

        if '<<<' in source and '>>>' in source:
            return self._run_mixed(source)
        
        if language is None:
            blocks = self._split_into_blocks(source)
            if len(blocks) > 1:
                return self._run_auto_mixed(source)
            language = self.detect_language(source, filename)
        
        if language == Language.HTML:
            return self._run_html(source)
        if language == Language.JSON:
            return self._run_json(source)
        
        if language == Language.NYX:
            return self._run_nyx(source, filename=filename)
        
        return self._run_external(source, language)
    
    def _run_auto_mixed(self, source):
        blocks = self._split_into_blocks(source)
        results = []
        
        for block_text, lang in blocks:
            if not block_text.strip():
                continue
            success, result, error = self._run_single_block(block_text, lang)
            if not success:
                return False, None, error
            results.append(result)
        
        return True, results, None
    
    def _run_single_block(self, source, language):
        if language == Language.NYX:
            return self._run_nyx(source, filename="")
        return self._run_external(source, language)

    def run_file(self, filepath):
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                source = f.read()
        except Exception as e:
            return False, None, f"Error: {e}"
        
        ext = os.path.splitext(filepath)[1].lower()
        if ext in ('.ny', '.nyx'):
            # Always run Nyx sources with the Nyx runner
            ok, error = self._validate_nyx_only_source(source, filepath)
            if not ok:
                return False, None, error
            return self.run(source, Language.NYX, filepath)
        
        return self.run(source, filename=filepath)
    
    def _run_mixed(self, source):
        lines = source.split('\n')
        results = []
        i = 0
        current_code = []
        current_lang = Language.NYX
        
        while i < len(lines):
            line = lines[i]
            stripped = line.strip()
            
            if stripped.startswith('<<<'):
                if current_code:
                    success, result, error = self.run('\n'.join(current_code), current_lang)
                    if not success:
                        return False, None, error
                    if result:
                        results.append(result)
                
                inner = stripped[3:].strip()
                if not inner and i + 1 < len(lines):
                    next_line = lines[i+1].strip()
                    if next_line:
                        current_lang = self._parse_lang(next_line)
                        i += 2
                    else:
                        current_lang = Language.PYTHON
                        i += 1
                else:
                    current_lang = self._parse_lang(inner) if inner else Language.PYTHON
                    i += 1
                current_code = []
                continue
            
            if stripped == '>>>':
                if current_code:
                    success, result, error = self.run('\n'.join(current_code), current_lang)
                    if not success:
                        return False, None, error
                    if result:
                        results.append(result)
                current_code = []
                i += 1
                continue
            
            current_code.append(line)
            i += 1
        
        if current_code:
            success, result, error = self.run('\n'.join(current_code), current_lang)
            if not success:
                return False, None, error
            if result:
                results.append(result)
        
        return True, results, None
    
    def _parse_lang(self, name):
        name = name.lower()
        m = {
            'python': Language.PYTHON, 'py': Language.PYTHON,
            'javascript': Language.JAVASCRIPT, 'js': Language.JAVASCRIPT,
            'ruby': Language.RUBY, 'rb': Language.RUBY,
            'php': Language.PHP, 'perl': Language.PERL,
            'lua': Language.LUA, 'r': Language.R,
            'julia': Language.JULIA, 'c': Language.C,
            'cpp': Language.CPP, 'rust': Language.RUST,
            'go': Language.GO, 'java': Language.JAVA,
            'kotlin': Language.KOTLIN, 'bash': Language.BASH,
            'shell': Language.BASH, 'html': Language.HTML,
            'css': Language.CSS, 'json': Language.JSON,
            'sql': Language.SQL, 'nyx': Language.NYX, 'ny': Language.NYX,
        }
        return m.get(name, Language.PYTHON)
    
    def _run_html(self, source):
        try:
            temp_dir = self._get_temp_dir()
            html_file = os.path.join(temp_dir, "temp.html")
            with open(html_file, 'w') as f:
                f.write(source)
            webbrowser.open(f'file://{html_file}')
            return True, f"Opened in browser: {html_file}", None
        except Exception as e:
            return True, source, None
    
    def _run_json(self, source):
        try:
            import json
            return True, json.dumps(json.loads(source), indent=2), None
        except Exception as e:
            return False, None, f"Invalid JSON: {e}"
    
    def _run_nyx(self, source, filename=''):
        ok, result, error = self._run_nyx_treewalker(source)
        if ok:
            return ok, result, error

        # Fallback runtime: more tolerant and extension-driven.
        fb_ok, fb_result, fb_error = self._run_nyx_compat(source, filename=filename)
        if fb_ok:
            return True, fb_result, None

        details = f"Tree-walker error: {error}"
        if fb_error:
            details += f" | Compatibility runtime error: {fb_error}"
        return False, None, details

    def _run_nyx_treewalker(self, source):
        try:
            sys.path.insert(0, os.getcwd())
            from src.lexer import Lexer
            from src.parser import Parser
            from src.interpreter import Interpreter, Environment, Function
            from src.stability import load_stability_config
            
            lexer = Lexer(source)
            parser = Parser(lexer)
            program = parser.parse()
            
            if parser.errors:
                return False, None, f"Parse errors: {parser.errors}"
            
            interpreter = Interpreter()
            env = Environment()
            result = interpreter.eval(program, env)

            # Stable entrypoint behavior: auto-run main() when present.
            stability = load_stability_config()
            if stability.auto_call_main:
                maybe_main = env.get("main")
                if isinstance(maybe_main, Function):
                    called_env = interpreter._extend_function_env(maybe_main, [])
                    result = interpreter.eval(maybe_main.body, called_env)
                elif callable(maybe_main):
                    result = maybe_main()
            
            return True, result, None
        except Exception as e:
            return False, None, str(e)

    def _run_nyx_compat(self, source, filename=''):
        try:
            sys.path.insert(0, os.getcwd())
            from nyx_runtime import NyxInterpreter

            runtime = NyxInterpreter()
            result = runtime.run(source, filename=filename or "<memory>")
            return True, result, None
        except Exception as e:
            return False, None, str(e)
    
    def _run_external(self, source, language):
        cmd_map = {
            Language.PYTHON: 'python',
            Language.JAVASCRIPT: 'node',
            Language.RUBY: 'ruby',
            Language.PHP: 'php',
            Language.PERL: 'perl',
            Language.LUA: 'lua',
            Language.R: 'Rscript',
            Language.BASH: 'bash',
        }
        
        cmd = cmd_map.get(language)
        if not cmd:
            return False, None, f"No interpreter for {language.value}"
        
        if not shutil.which(cmd):
            return False, None, f"Please install {cmd}"
        
        try:
            temp_dir = self._get_temp_dir()
            ext_map = {Language.PYTHON: '.py', Language.JAVASCRIPT: '.js',
                      Language.RUBY: '.rb', Language.PHP: '.php'}
            ext = ext_map.get(language, '.txt')
            temp_file = os.path.join(temp_dir, f"temp{ext}")
            
            with open(temp_file, 'w') as f:
                f.write(source)
            
            result = subprocess.run([cmd, temp_file], capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0:
                return True, result.stdout, None
            else:
                return False, result.stdout, result.stderr
        except subprocess.TimeoutExpired:
            return False, None, "Timed out"
        except Exception as e:
            return False, None, str(e)


def run_code(source, language=None):
    runner = PolyglotRunner()
    lang = Language(language.lower()) if language else None
    return runner.run(source, lang)


def run_file(filepath):
    runner = PolyglotRunner()
    return runner.run_file(filepath)
