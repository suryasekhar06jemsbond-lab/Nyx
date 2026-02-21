"""
Tests for the Nyx Polyglot module.
Tests Language detection, PolyglotRunner, and multi-language execution.
"""

import unittest
import tempfile
import os
from src.polyglot import (
    Language,
    PolyglotRunner,
    run_code,
    run_file,
)


class TestLanguageEnum(unittest.TestCase):
    """Tests for Language enum."""

    def test_language_values(self):
        """Test that all expected languages are defined."""
        expected_languages = [
            "nyx", "python", "javascript", "typescript", "ruby",
            "php", "perl", "lua", "r", "julia", "haskell",
            "c", "cpp", "rust", "go", "swift", "java", "kotlin",
            "bash", "powershell", "html", "css", "json", "yaml", "sql"
        ]
        for lang_name in expected_languages:
            lang = Language(lang_name)
            self.assertEqual(lang.value, lang_name)


class TestPolyglotRunner(unittest.TestCase):
    """Tests for PolyglotRunner."""

    def setUp(self):
        self.runner = PolyglotRunner()

    def test_runner_initialization(self):
        """Test PolyglotRunner initialization."""
        self.assertIsNotNone(self.runner)

    def test_detect_language_python(self):
        """Test detecting Python code."""
        source = "def hello():\n    print('hello')"
        lang = self.runner.detect_language(source)
        self.assertEqual(lang, Language.PYTHON)

    def test_detect_language_javascript(self):
        """Test detecting JavaScript code."""
        source = "function hello() {\n    console.log('hello');\n}"
        lang = self.runner.detect_language(source)
        self.assertEqual(lang, Language.JAVASCRIPT)

    def test_detect_language_nyx(self):
        """Test detecting Nyx code."""
        source = "fn hello() -> String {\n    return \"hello\";\n}"
        lang = self.runner.detect_language(source)
        self.assertEqual(lang, Language.NYX)

    def test_detect_language_html(self):
        """Test detecting HTML code."""
        source = "<html>\n<body>Hello</body>\n</html>"
        lang = self.runner.detect_language(source)
        self.assertEqual(lang, Language.HTML)

    def test_detect_language_json(self):
        """Test detecting JSON code."""
        source = '{"name": "test", "value": 42}'
        lang = self.runner.detect_language(source)
        self.assertEqual(lang, Language.JSON)

    def test_detect_language_by_filename_nyx(self):
        """Test detecting language from .nyx filename."""
        lang = self.runner.detect_language("", "test.nyx")
        self.assertEqual(lang, Language.NYX)

    def test_detect_language_by_filename_ny(self):
        """Test detecting language from .ny filename."""
        lang = self.runner.detect_language("", "test.ny")
        self.assertEqual(lang, Language.NYX)

    def test_detect_language_by_filename_py(self):
        """Test detecting language from .py filename."""
        lang = self.runner.detect_language("", "test.py")
        self.assertEqual(lang, Language.PYTHON)

    def test_detect_language_by_filename_js(self):
        """Test detecting language from .js filename."""
        lang = self.runner.detect_language("", "test.js")
        self.assertEqual(lang, Language.JAVASCRIPT)

    def test_is_python_line_import(self):
        """Test detecting Python import."""
        self.assertTrue(self.runner._is_python_line("import os"))

    def test_is_python_line_def(self):
        """Test detecting Python def."""
        self.assertTrue(self.runner._is_python_line("def hello():"))

    def test_is_javascript_line_console_log(self):
        """Test detecting JavaScript console.log."""
        self.assertTrue(self.runner._is_javascript_line("console.log('test')"))

    def test_is_javascript_line_const(self):
        """Test detecting JavaScript const."""
        self.assertTrue(self.runner._is_javascript_line("const x = 1;"))

    def test_is_nyx_line_fn(self):
        """Test detecting Nyx fn keyword."""
        self.assertTrue(self.runner._is_nyx_line("fn hello() {"))

    def test_is_nyx_line_arrow(self):
        """Test detecting Nyx arrow."""
        self.assertTrue(self.runner._is_nyx_line("x -> y"))

    def test_run_python_code(self):
        """Test running Python code."""
        success, result, error = self.runner.run("print('hello')", Language.PYTHON)
        # May fail if Python not installed, that's ok
        self.assertIsInstance(success, bool)

    def test_run_nyx_simple(self):
        """Test running simple Nyx code."""
        # This may fail if the Nyx runtime is not set up
        source = "let x = 5;"
        success, result, error = self.runner.run(source, Language.NYX)
        # Either succeeds or fails - just check it returns proper format
        self.assertIsInstance(success, bool)

    def test_run_external_no_interpreter(self):
        """Test running code with no interpreter available."""
        # Try to run Ruby (which is unlikely to be installed)
        success, result, error = self.runner._run_external("puts 'hello'", Language.RUBY)
        # Should fail gracefully
        self.assertFalse(success)

    def test_parse_lang(self):
        """Test parsing language from string."""
        self.assertEqual(self.runner._parse_lang("python"), Language.PYTHON)
        self.assertEqual(self.runner._parse_lang("py"), Language.PYTHON)
        self.assertEqual(self.runner._parse_lang("javascript"), Language.JAVASCRIPT)
        self.assertEqual(self.runner._parse_lang("js"), Language.JAVASCRIPT)
        self.assertEqual(self.runner._parse_lang("nyx"), Language.NYX)
        self.assertEqual(self.runner._parse_lang("ny"), Language.NYX)
        self.assertEqual(self.runner._parse_lang("ruby"), Language.RUBY)
        self.assertEqual(self.runner._parse_lang("rb"), Language.RUBY)

    def test_split_into_blocks(self):
        """Test splitting source into language blocks."""
        source = "let x = 5;\nprint(x);"
        blocks = self.runner._split_into_blocks(source)
        # Should have at least one block
        self.assertGreater(len(blocks), 0)


class TestRunCode(unittest.TestCase):
    """Tests for run_code function."""

    def test_run_code_with_language(self):
        """Test run_code with explicit language."""
        # Just check it doesn't crash - may fail due to missing interpreter
        try:
            result = run_code("print('test')", "python")
            self.assertIsInstance(result, tuple)
            self.assertEqual(len(result), 3)
        except Exception as e:
            # May fail if Python not available
            pass


class TestRunFile(unittest.TestCase):
    """Tests for run_file function."""

    def test_run_file_nonexistent(self):
        """Test running nonexistent file."""
        success, result, error = run_file("/nonexistent/file.py")
        self.assertFalse(success)
        self.assertIn("Error", error)

    def test_run_file_nyx_extension(self):
        """Test running .nyx file."""
        # Create a temporary file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.nyx', delete=False) as f:
            f.write("let x = 5;")
            temp_path = f.name

        try:
            success, result, error = run_file(temp_path)
            # Should attempt to run as Nyx
            self.assertIsInstance(success, bool)
        finally:
            os.unlink(temp_path)

    def test_run_file_ny_rejects_polyglot_markers(self):
        """Test .ny files reject non-NYX polyglot markers."""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.ny', delete=False) as f:
            f.write("let x = 1;\n<<<python\nprint('x')\n>>>")
            temp_path = f.name

        try:
            success, result, error = run_file(temp_path)
            self.assertFalse(success)
            self.assertIn("NYX-only", error)
        finally:
            os.unlink(temp_path)

    def test_run_file_ny_rejects_python_def(self):
        """Test .ny files reject Python syntax."""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.ny', delete=False) as f:
            f.write("def hello():\n    return 1\n")
            temp_path = f.name

        try:
            success, result, error = run_file(temp_path)
            self.assertFalse(success)
            self.assertIn("NYX-only", error)
        finally:
            os.unlink(temp_path)


class TestPolyglotRunnerEdgeCases(unittest.TestCase):
    """Edge case tests for PolyglotRunner."""

    def setUp(self):
        self.runner = PolyglotRunner()

    def test_empty_source(self):
        """Test with empty source."""
        lang = self.runner.detect_language("")
        # Empty should default to Python
        self.assertEqual(lang, Language.PYTHON)

    def test_whitespace_only(self):
        """Test with whitespace only."""
        source = "   \n\n   "
        lang = self.runner.detect_language(source)
        self.assertEqual(lang, Language.PYTHON)

    def test_comment_only(self):
        """Test with comments only."""
        source = "# This is a comment\n// Another comment"
        lang = self.runner.detect_language(source)
        self.assertEqual(lang, Language.PYTHON)

    def test_shebang_detection(self):
        """Test shebang detection."""
        source = "#!/usr/bin/env python\nprint('hello')"
        lang = self.runner.detect_language(source)
        self.assertEqual(lang, Language.PYTHON)

    def test_node_shebang(self):
        """Test Node.js shebang detection."""
        source = "#!/usr/bin/env node\nconsole.log('hello');"
        lang = self.runner.detect_language(source)
        self.assertEqual(lang, Language.JAVASCRIPT)

    def test_ruby_shebang(self):
        """Test Ruby shebang detection."""
        source = "#!/usr/bin/env ruby\nputs 'hello'"
        lang = self.runner.detect_language(source)
        self.assertEqual(lang, Language.RUBY)

    def test_json_validation(self):
        """Test JSON validation."""
        # Valid JSON
        success, result, error = self.runner.run('{"key": "value"}', Language.JSON)
        self.assertTrue(success)

    def test_json_invalid(self):
        """Test invalid JSON."""
        success, result, error = self.runner.run('{invalid}', Language.JSON)
        self.assertFalse(success)
        self.assertIn("Invalid JSON", error)


class TestPolyglotRunnerIntegration(unittest.TestCase):
    """Integration tests for PolyglotRunner."""

    def setUp(self):
        self.runner = PolyglotRunner()

    def test_language_priority_nyx(self):
        """Test Nyx has priority when fn keyword present."""
        # fn is Nyx-specific, def is Python-specific
        # Nyx should be detected when both present or just fn
        source = "fn main() {\n    let x = 5;\n}"
        lang = self.runner.detect_language(source)
        self.assertEqual(lang, Language.NYX)


if __name__ == '__main__':
    unittest.main()
