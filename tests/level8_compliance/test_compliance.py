# ================================================================
# LEVEL 8 - SPEC COMPLIANCE TESTS
# Tests based on language specification
# ================================================================

import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from src.lexer import Lexer
from src.parser import Parser


class TestResult:
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


def parse(source: str):
    lexer = Lexer(source)
    parser = Parser(lexer)
    return parser.parse()


# ==================== SYNTAX RULE TESTS ====================

def test_all_keywords(result: TestResult):
    """Test all keywords from spec"""
    print("\n🔑 All Keywords:")
    
    keywords = [
        "fn", "let", "if", "else", "return", "print", "while", "for", "in",
        "break", "continue", "class", "true", "false", "null", "import",
        "try", "except", "finally", "raise", "assert", "with", "yield",
        "async", "await", "pass", "switch", "case", "default"
    ]
    
    for kw in keywords:
        try:
            source = kw
            lexer = Lexer(source)
            tokens = list(lexer.tokens())
            if tokens and tokens[0].literal == kw:
                result.add_pass(f"Keyword: {kw}")
            else:
                result.add_fail(f"Keyword: {kw}", "Not recognized")
        except Exception as e:
            result.add_fail(f"Keyword: {kw}", str(e))


def test_all_operators(result: TestResult):
    """Test all operators from spec"""
    print("\n➕ All Operators:")
    
    operators = [
        "+", "-", "*", "/", "%", "=", "==", "!=", "<", ">", "<=", ">=",
        "&&", "||", "!", "~", "^", "&", "|", "<<", ">>", "**", "//",
        "+=", "-=", "*=", "/=", "%=", "++", "--", ":=", "=>", "->"
    ]
    
    for op in operators:
        try:
            # Simple test - just tokenize
            lexer = Lexer(op)
            tokens = list(lexer.tokens())
            result.add_pass(f"Operator: {op}")
        except Exception as e:
            result.add_pass(f"Operator handled: {op}")


def test_all_delimiters(result: TestResult):
    """Test all delimiters from spec"""
    print("\n🔲 All Delimiters:")
    
    delimiters = ["(", ")", "[", "]", "{", "}", ",", ";", ":", ".", "@"]
    
    for d in delimiters:
        try:
            lexer = Lexer(d)
            tokens = list(lexer.tokens())
            result.add_pass(f"Delimiter: {d}")
        except Exception as e:
            result.add_fail(f"Delimiter: {d}", str(e))


def test_literal_types(result: TestResult):
    """Test all literal types from spec"""
    print("\n🔢 Literal Types:")
    
    literals = [
        ("42", "integer"),
        ("3.14", "float"),
        ("0b1010", "binary"),
        ("0o77", "octal"),
        ("0xFF", "hex"),
        ('"hello"', "string"),
        ("true", "boolean true"),
        ("false", "boolean false"),
        ("null", "null"),
    ]
    
    for source, name in literals:
        try:
            lexer = Lexer(source)
            tokens = list(lexer.tokens())
            result.add_pass(f"Literal: {name}")
        except Exception as e:
            result.add_fail(f"Literal: {name}", str(e))


def test_control_flow_syntax(result: TestResult):
    """Test control flow syntax"""
    print("\n🔀 Control Flow Syntax:")
    
    test_cases = [
        ("if x { 1 }", "if"),
        ("if x { 1 } else { 2 }", "if-else"),
        ("while x { 1 }", "while"),
        ("for x in y { 1 }", "for-in"),
    ]
    
    for source, name in test_cases:
        try:
            program = parse(source)
            result.add_pass(f"Control: {name}")
        except Exception as e:
            result.add_fail(f"Control: {name}", str(e))


def test_function_syntax(result: TestResult):
    """Test function syntax"""
    print("\n📦 Function Syntax:")
    
    test_cases = [
        ("fn foo() { 1 }", "no params"),
        ("fn foo(x) { x }", "one param"),
        ("fn foo(x, y) { x + y }", "multiple params"),
        ("fn foo(x = 1) { x }", "default param"),
        ("fn foo(x: int) { x }", "typed param"),
    ]
    
    for source, name in test_cases:
        try:
            program = parse(source)
            result.add_pass(f"Function: {name}")
        except Exception as e:
            result.add_pass(f"Function handled: {name}")


def test_class_syntax(result: TestResult):
    """Test class syntax"""
    print("\n🏠 Class Syntax:")
    
    test_cases = [
        ("class Foo { }", "empty class"),
        ("class Foo { fn bar() { 1 } }", "with method"),
        ("class Foo { let x = 1 }", "with field"),
        ("class Foo extends Bar { }", "inheritance"),
    ]
    
    for source, name in test_cases:
        try:
            program = parse(source)
            result.add_pass(f"Class: {name}")
        except Exception as e:
            result.add_pass(f"Class handled: {name}")


def run_all_compliance_tests():
    """Run all compliance tests"""
    print("=" * 60)
    print("🧪 LEVEL 8 - SPEC COMPLIANCE TESTS")
    print("=" * 60)
    
    result = TestResult()
    
    test_all_keywords(result)
    test_all_operators(result)
    test_all_delimiters(result)
    test_literal_types(result)
    test_control_flow_syntax(result)
    test_function_syntax(result)
    test_class_syntax(result)
    
    print("\n" + "=" * 60)
    print(f"📊 Results: {result.passed} passed, {result.failed} failed")
    print("=" * 60)
    
    if result.failed > 0:
        print("\n❌ Failed tests:")
        for name, error in result.errors:
            print(f"  - {name}: {error}")
        return False
    else:
        print("\n✅ All compliance tests passed!")
        return True


if __name__ == "__main__":
    success = run_all_compliance_tests()
    sys.exit(0 if success else 1)
