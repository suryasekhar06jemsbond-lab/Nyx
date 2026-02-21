# ================================================================
# LEVEL 1 - LEXER TESTS (Tokenization)
# Comprehensive test suite for the Nyx language tokenizer
# ================================================================

import sys
import os
import io

# Set UTF-8 encoding for stdout
try:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    elif hasattr(sys.stdout, "buffer"):
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
except Exception:
    pass

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from src.lexer import Lexer
from src.token_types import TokenType


class TestResult:
    """Container for test results"""
    def __init__(self):
        self.passed = 0
        self.failed = 0
        self.errors = []
    
    def add_pass(self, name):
        self.passed += 1
        print(f"  ✓ {name}")
    
    def add_fail(self, name, error):
        self.failed += 1
        self.errors.append((name, error))
        print(f"  ✗ {name}: {error}")


def tokenize(source: str) -> list:
    """Helper function to tokenize source code"""
    lexer = Lexer(source)
    tokens = list(lexer.tokens())
    return tokens


def test_basic_identifiers(result: TestResult):
    """Test basic identifier tokenization"""
    print("\n[BASIC] Basic Identifiers:")
    
    test_cases = [
        ("x", TokenType.IDENT, "x"),
        ("foo", TokenType.IDENT, "foo"),
        ("myVariable", TokenType.IDENT, "myVariable"),
        ("_private", TokenType.IDENT, "_private"),
        ("CamelCase", TokenType.IDENT, "CamelCase"),
        ("snake_case", TokenType.IDENT, "snake_case"),
    ]
    
    for source, expected_type, expected_literal in test_cases:
        try:
            tokens = tokenize(source)
            if len(tokens) >= 2 and tokens[0].type == expected_type and tokens[0].literal == expected_literal:
                result.add_pass(f"Identifier: {source}")
            else:
                result.add_fail(f"Identifier: {source}", f"Expected {expected_type}({expected_literal}), got {tokens[0] if tokens else 'none'}")
        except Exception as e:
            result.add_fail(f"Identifier: {source}", str(e))


def test_keywords(result: TestResult):
    """Test keyword tokenization"""
    print("\n[KEYWORDS] Keywords:")
    
    keywords = [
        ("fn", TokenType.FUNCTION),
        ("let", TokenType.LET),
        ("if", TokenType.IF),
        ("else", TokenType.ELSE),
        ("return", TokenType.RETURN),
        ("print", TokenType.PRINT),
        ("while", TokenType.WHILE),
        ("for", TokenType.FOR),
        ("in", TokenType.IN),
        ("break", TokenType.BREAK),
        ("continue", TokenType.CONTINUE),
        ("class", TokenType.CLASS),
        ("true", TokenType.TRUE),
        ("false", TokenType.FALSE),
        ("null", TokenType.NULL),
        ("import", TokenType.IMPORT),
        ("try", TokenType.TRY),
        ("except", TokenType.EXCEPT),
    ]
    
    for keyword, expected_type in keywords:
        try:
            tokens = tokenize(keyword)
            if tokens and tokens[0].type == expected_type:
                result.add_pass(f"Keyword: {keyword}")
            else:
                result.add_fail(f"Keyword: {keyword}", f"Expected {expected_type}, got {tokens[0].type if tokens else 'none'}")
        except Exception as e:
            result.add_fail(f"Keyword: {keyword}", str(e))


def test_numbers(result: TestResult):
    """Test number tokenization (int, float, negative, large)"""
    print("\n[NUMBERS] Numbers:")
    
    test_cases = [
        # (source, expected_type, expected_literal)
        ("0", TokenType.INT, "0"),
        ("42", TokenType.INT, "42"),
        ("1234567890", TokenType.INT, "1234567890"),
        ("3.14", TokenType.FLOAT, "3.14"),
        ("0.5", TokenType.FLOAT, "0.5"),
        (".5", TokenType.FLOAT, ".5"),
        ("1e10", TokenType.FLOAT, "1e10"),
        ("1.5e10", TokenType.FLOAT, "1.5e10"),
        ("1e-5", TokenType.FLOAT, "1e-5"),
        ("-42", TokenType.INT, "-42"),
        ("-3.14", TokenType.FLOAT, "-3.14"),
        ("0b1010", TokenType.BINARY, "1010"),
        ("0o77", TokenType.OCTAL, "77"),
        ("0xFF", TokenType.HEX, "FF"),
    ]
    
    for source, expected_type, expected_literal in test_cases:
        try:
            tokens = tokenize(source)
            if tokens and tokens[0].type == expected_type:
                result.add_pass(f"Number: {source}")
            else:
                result.add_fail(f"Number: {source}", f"Expected {expected_type}, got {tokens[0] if tokens else 'none'}")
        except Exception as e:
            result.add_fail(f"Number: {source}", str(e))


def test_strings(result: TestResult):
    """Test string tokenization (empty, unicode, escaped)"""
    print("\n[STRINGS] Strings:")
    
    test_cases = [
        ('""', ""),
        ('"hello"', "hello"),
        ("''", ""),
        ("'world'", "world"),
        ('"Hello World"', "Hello World"),
        ('"Unicode: αβγδ"', "Unicode: αβγδ"),
        ('"New\\nline"', "New\nline"),
        ('"Tab\\there"', "Tab\there"),
        ('"Quote\\""', 'Quote"'),
        ('"Backslash\\\\"', "Backslash\\"),
    ]
    
    for source, expected_value in test_cases:
        try:
            tokens = tokenize(source)
            if tokens and tokens[0].type == TokenType.STRING:
                result.add_pass(f"String: {source}")
            else:
                result.add_fail(f"String: {source}", f"Expected STRING, got {tokens[0] if tokens else 'none'}")
        except Exception as e:
            result.add_fail(f"String: {source}", str(e))


def test_operators(result: TestResult):
    """Test operator tokenization"""
    print("\n[OPERATORS] Operators:")
    
    operators = [
        ("+", TokenType.PLUS),
        ("-", TokenType.MINUS),
        ("*", TokenType.ASTERISK),
        ("/", TokenType.SLASH),
        ("%", TokenType.MODULO),
        ("==", TokenType.EQ),
        ("!=", TokenType.NOT_EQ),
        (">=", TokenType.GE),
        ("<=", TokenType.LE),
        (">", TokenType.GT),
        ("<", TokenType.LT),
        ("=", TokenType.ASSIGN),
        ("+=", TokenType.PLUS_ASSIGN),
        ("-=", TokenType.MINUS_ASSIGN),
        ("*=", TokenType.ASTERISK_ASSIGN),
        ("/=", TokenType.SLASH_ASSIGN),
        ("&&", TokenType.LOGICAL_AND),
        ("||", TokenType.LOGICAL_OR),
        ("**", TokenType.POWER),
        ("//", TokenType.FLOOR_DIVIDE),
        (":=", TokenType.COLON_ASSIGN),
        ("=>", TokenType.ARROW),
    ]
    
    for op, expected_type in operators:
        try:
            tokens = tokenize(op)
            if tokens and tokens[0].type == expected_type:
                result.add_pass(f"Operator: {op}")
            else:
                result.add_fail(f"Operator: {op}", f"Expected {expected_type}, got {tokens[0] if tokens else 'none'}")
        except Exception as e:
            result.add_fail(f"Operator: {op}", str(e))


def test_delimiters(result: TestResult):
    """Test delimiter tokenization"""
    print("\n[DELIMITERS] Delimiters:")
    
    delimiters = [
        ("(", TokenType.LPAREN),
        (")", TokenType.RPAREN),
        ("{", TokenType.LBRACE),
        ("}", TokenType.RBRACE),
        ("[", TokenType.LBRACKET),
        ("]", TokenType.RBRACKET),
        (",", TokenType.COMMA),
        (";", TokenType.SEMICOLON),
        (":", TokenType.COLON),
        (".", TokenType.DOT),
    ]
    
    for delim, expected_type in delimiters:
        try:
            tokens = tokenize(delim)
            if tokens and tokens[0].type == expected_type:
                result.add_pass(f"Delimiter: {delim}")
            else:
                result.add_fail(f"Delimiter: {delim}", f"Expected {expected_type}, got {tokens[0] if tokens else 'none'}")
        except Exception as e:
            result.add_fail(f"Delimiter: {delim}", str(e))


def test_long_identifier(result: TestResult):
    """Test very long identifier (10,000 chars)"""
    print("\n[LONG] Long Identifiers:")
    
    try:
        long_ident = "a" * 10000
        tokens = tokenize(long_ident)
        if tokens and tokens[0].type == TokenType.IDENT and len(tokens[0].literal) == 10000:
            result.add_pass("Long identifier (10,000 chars)")
        else:
            result.add_fail("Long identifier (10,000 chars)", f"Failed to tokenize long identifier")
    except Exception as e:
        result.add_fail("Long identifier (10,000 chars)", str(e))


def test_long_number(result: TestResult):
    """Test very long number"""
    print("\n[LONG] Long Numbers:")
    
    try:
        long_num = "9" * 1000
        tokens = tokenize(long_num)
        if tokens and tokens[0].type == TokenType.INT:
            result.add_pass("Long number (1,000 digits)")
        else:
            result.add_fail("Long number (1,000 digits)", f"Failed to tokenize long number")
    except Exception as e:
        result.add_fail("Long number (1,000 digits)", str(e))


def test_weird_whitespace(result: TestResult):
    """Test weird whitespace (tabs, CRLF, mixed)"""
    print("\n[WHITESPACE] Weird Whitespace:")
    
    test_cases = [
        ("\t\tx", "x"),
        ("\r\n\r\nx", "x"),
        (" \t \r\n x", "x"),
        ("x \t y", "x"),
    ]
    
    for source, expected_first in test_cases:
        try:
            tokens = tokenize(source)
            if tokens and tokens[0].literal == expected_first:
                result.add_pass(f"Weird whitespace: {repr(source)}")
            else:
                result.add_fail(f"Weird whitespace: {repr(source)}", f"Got {tokens[0].literal if tokens else 'none'}")
        except Exception as e:
            result.add_fail(f"Weird whitespace: {repr(source)}", str(e))


def test_comments(result: TestResult):
    """Test comments inside code"""
    print("\n[COMMENTS] Comments:")
    
    test_cases = [
        ("# this is a comment\nx", "x"),
        ("x # inline comment", "x"),
        ("# comment 1\n# comment 2\nx", "x"),
    ]
    
    for source, expected_first in test_cases:
        try:
            tokens = tokenize(source)
            if tokens and tokens[0].literal == expected_first:
                result.add_pass(f"Comment: {repr(source[:30])}")
            else:
                result.add_fail(f"Comment: {repr(source[:30])}", f"Got {tokens[0].literal if tokens else 'none'}")
        except Exception as e:
            result.add_fail(f"Comment: {repr(source[:30])}", str(e))


def test_nested_comments(result: TestResult):
    """Test nested comments"""
    print("\n[COMMENTS] Nested Comments:")
    
    test_cases = [
        ("/* comment */ x", "x"),
        ("x /* comment */", "x"),
        ("/* outer /* inner */ outer */ x", "x"),
    ]
    
    for source, expected_first in test_cases:
        try:
            tokens = tokenize(source)
            if tokens and tokens[0].literal == expected_first:
                result.add_pass(f"Nested comment: {repr(source[:30])}")
            else:
                result.add_fail(f"Nested comment: {repr(source[:30])}", f"Got {tokens[0].literal if tokens else 'none'}")
        except Exception as e:
            result.add_fail(f"Nested comment: {repr(source[:30])}", str(e))


def test_corruption_random_binary(result: TestResult):
    """Test with random binary characters"""
    print("\n[BINARY] Corruption - Random Binary:")
    
    test_cases = [
        "\x00\x01\x02",
        "\xff\xfe\xfd",
        "\x80\x81\x82",
    ]
    
    for source in test_cases:
        try:
            tokens = tokenize(source)
            # Should not crash, may produce ILLEGAL tokens
            result.add_pass(f"Binary corruption: {repr(source[:10])}")
        except Exception as e:
            result.add_fail(f"Binary corruption: {repr(source[:10])}", str(e))


def test_corruption_invalid_unicode(result: TestResult):
    """Test with invalid unicode"""
    print("\n[UNICODE] Corruption - Invalid Unicode:")
    
    test_cases = [
        "\ud800\udc00",  # Surrogate pair
        "\ufffe",  # BOM
        "\xc0\x80",  # Overlong encoding
    ]
    
    for source in test_cases:
        try:
            tokens = tokenize(source)
            result.add_pass(f"Invalid unicode: {repr(source)}")
        except Exception as e:
            result.add_fail(f"Invalid unicode: {repr(source)}", str(e))


def test_half_written_tokens(result: TestResult):
    """Test half-written tokens"""
    print("\n[HALF] Half-Written Tokens:")
    
    test_cases = [
        "123",  # Complete number
        "12",   # Half number
        "1",    # Quarter number
        '"hello',  # Unclosed string
        "'wor",    # Unclosed char
    ]
    
    for source in test_cases:
        try:
            tokens = tokenize(source)
            # Should not crash
            result.add_pass(f"Half-written: {repr(source)}")
        except Exception as e:
            result.add_fail(f"Half-written: {repr(source)}", str(e))


def test_line_numbers(result: TestResult):
    """Test that line numbers are tracked correctly"""
    print("\n[LINES] Line Numbers:")
    
    source = "x\ny\nz"
    try:
        tokens = tokenize(source)
        if len(tokens) >= 3:
            if tokens[0].line == 1 and tokens[1].line == 2 and tokens[2].line == 3:
                result.add_pass("Line number tracking")
            else:
                result.add_fail("Line number tracking", f"Lines: {[(t.literal, t.line) for t in tokens[:3]]}")
        else:
            result.add_fail("Line number tracking", "Not enough tokens")
    except Exception as e:
        result.add_fail("Line number tracking", str(e))


def test_column_numbers(result: TestResult):
    """Test that column numbers are tracked correctly"""
    print("\n[COLUMNS] Column Numbers:")
    
    source = "  x"
    try:
        tokens = tokenize(source)
        if tokens and tokens[0].literal == "x":
            if tokens[0].column == 3:  # x is at column 3 (after two spaces)
                result.add_pass("Column number tracking")
            else:
                result.add_fail("Column number tracking", f"Expected column 3, got {tokens[0].column}")
        else:
            result.add_fail("Column number tracking", "x token not found")
    except Exception as e:
        result.add_fail("Column number tracking", str(e))


def run_all_lexer_tests():
    """Run all lexer tests"""
    print("=" * 60)
    print("🧪 LEVEL 1 - LEXER TESTS (Tokenization)")
    print("=" * 60)
    
    result = TestResult()
    
    # Basic token tests
    test_basic_identifiers(result)
    test_keywords(result)
    test_numbers(result)
    test_strings(result)
    test_operators(result)
    test_delimiters(result)
    
    # Edge case tests
    test_long_identifier(result)
    test_long_number(result)
    test_weird_whitespace(result)
    test_comments(result)
    test_nested_comments(result)
    
    # Corruption tests
    test_corruption_random_binary(result)
    test_corruption_invalid_unicode(result)
    test_half_written_tokens(result)
    
    # Position tracking tests
    test_line_numbers(result)
    test_column_numbers(result)
    
    # Summary
    print("\n" + "=" * 60)
    print(f"📊 Results: {result.passed} passed, {result.failed} failed")
    print("=" * 60)
    
    if result.failed > 0:
        print("\n❌ Failed tests:")
        for name, error in result.errors:
            print(f"  - {name}: {error}")
        return False
    else:
        print("\n✅ All lexer tests passed!")
        return True


if __name__ == "__main__":
    success = run_all_lexer_tests()
    sys.exit(0 if success else 1)
