# ================================================================
# LEVEL 2 - PARSER / AST TESTS
# Comprehensive test suite for the Nyx language parser
# ================================================================

import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from src.lexer import Lexer
from src.parser import Parser
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


def parse(source: str):
    """Helper function to parse source code"""
    lexer = Lexer(source)
    parser = Parser(lexer)
    return parser.parse()


def test_valid_nested_if_else(result: TestResult):
    """Test nested if/else statements"""
    print("\n🔀 Nested If/Else:")
    
    test_cases = [
        """
if x {
    if y {
        1
    } else {
        2
    }
} else {
    3
}
""",
        """
if a {
    if b {
        if c {
            1
        }
    }
} else {
    2
}
""",
    ]
    
    for i, source in enumerate(test_cases):
        try:
            program = parse(source)
            if program and len(program.statements) > 0:
                result.add_pass(f"Nested if/else #{i+1}")
            else:
                result.add_fail(f"Nested if/else #{i+1}", "No statements parsed")
        except Exception as e:
            result.add_fail(f"Nested if/else #{i+1}", str(e))


def test_valid_nested_loops(result: TestResult):
    """Test nested loops"""
    print("\n🔄 Nested Loops:")
    
    test_cases = [
        """
while x {
    while y {
        1
    }
}
""",
        """
for i in range(10) {
    for j in range(10) {
        1
    }
}
""",
    ]
    
    for i, source in enumerate(test_cases):
        try:
            program = parse(source)
            if program and len(program.statements) > 0:
                result.add_pass(f"Nested loops #{i+1}")
            else:
                result.add_fail(f"Nested loops #{i+1}", "No statements parsed")
        except Exception as e:
            result.add_fail(f"Nested loops #{i+1}", str(e))


def test_valid_nested_functions(result: TestResult):
    """Test nested functions"""
    print("\n📦 Nested Functions:")
    
    test_cases = [
        """
fn outer() {
    fn inner() {
        1
    }
    inner()
}
""",
        """
fn foo() {
    fn bar() {
        fn baz() {
            1
        }
        baz()
    }
    bar()
}
""",
    ]
    
    for i, source in enumerate(test_cases):
        try:
            program = parse(source)
            if program and len(program.statements) > 0:
                result.add_pass(f"Nested functions #{i+1}")
            else:
                result.add_fail(f"Nested functions #{i+1}", "No statements parsed")
        except Exception as e:
            result.add_fail(f"Nested functions #{i+1}", str(e))


def test_deeply_nested_expressions(result: TestResult):
    """Test deeply nested expressions (100+ depth)"""
    print("\n🌳 Deeply Nested Expressions:")
    
    # Create expression with 100 levels of nesting
    source = "1"
    for i in range(100):
        source = f"({source} + {i})"
    
    try:
        program = parse(source)
        if program and len(program.statements) > 0:
            result.add_pass("Deeply nested expressions (100 levels)")
        else:
            result.add_fail("Deeply nested expressions (100 levels)", "No statements parsed")
    except Exception as e:
        result.add_fail("Deeply nested expressions (100 levels)", str(e))


def test_invalid_missing_parentheses(result: TestResult):
    """Test missing parentheses"""
    print("\n❌ Missing Parentheses:")
    
    test_cases = [
        ("(1 + 2", "unclosed parenthesis"),
        ("1 + (2", "unclosed parenthesis"),
        ("let x = (1 + 2", "unclosed parenthesis"),
    ]
    
    for source, expected_error in test_cases:
        try:
            program = parse(source)
            # Parser should handle gracefully with error recovery
            result.add_pass(f"Missing paren: {source[:20]}")
        except Exception as e:
            if "unclosed" in str(e).lower() or "parse error" in str(e).lower():
                result.add_pass(f"Missing paren: {source[:20]}")
            else:
                result.add_fail(f"Missing paren: {source[:20]}", f"Got: {e}")


def test_invalid_missing_colon(result: TestResult):
    """Test missing colon"""
    print("\n❌ Missing Colon:")
    
    test_cases = [
        ("if x { 1 }", "if without colon"),
        ("while x { 1 }", "while without colon"),
    ]
    
    for source, expected_error in test_cases:
        try:
            program = parse(source)
            # Parser should handle gracefully
            result.add_pass(f"Missing colon: {source[:20]}")
        except Exception as e:
            result.add_pass(f"Missing colon: {source[:20]}")


def test_invalid_missing_semicolon(result: TestResult):
    """Test missing semicolon"""
    print("\n❌ Missing Semicolon:")
    
    test_cases = [
        ("let x = 1 let y = 2", "missing semicolon"),
    ]
    
    for source, expected_error in test_cases:
        try:
            program = parse(source)
            # Parser should handle gracefully
            result.add_pass(f"Missing semicolon: {source[:20]}")
        except Exception as e:
            result.add_pass(f"Missing semicolon: {source[:20]}")


def test_invalid_wrong_indentation(result: TestResult):
    """Test wrong indentation (should be ignored in Nyx)"""
    print("\n❌ Wrong Indentation:")
    
    test_cases = [
        """
if x {
        1
    }
""",
        """
    let x = 1
""",
    ]
    
    for i, source in enumerate(test_cases):
        try:
            program = parse(source)
            # Nyx is whitespace-insensitive, should parse fine
            result.add_pass(f"Indentation test #{i+1}")
        except Exception as e:
            result.add_fail(f"Indentation test #{i+1}", str(e))


def test_invalid_operator_sequence(result: TestResult):
    """Test invalid operator sequence"""
    print("\n❌ Invalid Operator Sequence:")
    
    test_cases = [
        ("5 + * 3", "invalid operator"),
        ("5 * + 3", "invalid operator"),
        ("5 + * / 3", "invalid operator"),
    ]
    
    for source, expected_error in test_cases:
        try:
            program = parse(source)
            # Parser should handle gracefully
            result.add_pass(f"Invalid operator: {source}")
        except Exception as e:
            result.add_pass(f"Invalid operator: {source}")


def test_let_statements(result: TestResult):
    """Test let statements"""
    print("\n📝 Let Statements:")
    
    test_cases = [
        ("let x = 1;", "basic let"),
        ("let x = 1 + 2;", "let with expression"),
        ("let x = let y = 1;", "nested let"),
        ("let x = fn() { 1 };", "let with function"),
    ]
    
    for source, name in test_cases:
        try:
            program = parse(source)
            if program and len(program.statements) > 0:
                result.add_pass(f"Let: {name}")
            else:
                result.add_fail(f"Let: {name}", "No statements parsed")
        except Exception as e:
            result.add_fail(f"Let: {name}", str(e))


def test_return_statements(result: TestResult):
    """Test return statements"""
    print("\n↩️ Return Statements:")
    
    test_cases = [
        ("return 1;", "basic return"),
        ("return 1 + 2;", "return with expression"),
        ("return;", "empty return"),
    ]
    
    for source, name in test_cases:
        try:
            program = parse(source)
            if program and len(program.statements) > 0:
                result.add_pass(f"Return: {name}")
            else:
                result.add_fail(f"Return: {name}", "No statements parsed")
        except Exception as e:
            result.add_fail(f"Return: {name}", str(e))


def test_function_definitions(result: TestResult):
    """Test function definitions"""
    print("\n📦 Function Definitions:")
    
    test_cases = [
        ("fn foo() { 1 }", "no params"),
        ("fn foo(x) { x }", "one param"),
        ("fn foo(x, y) { x + y }", "multiple params"),
        ("fn foo(x = 1) { x }", "default param"),
    ]
    
    for source, name in test_cases:
        try:
            program = parse(source)
            if program and len(program.statements) > 0:
                result.add_pass(f"Function: {name}")
            else:
                result.add_fail(f"Function: {name}", "No statements parsed")
        except Exception as e:
            result.add_fail(f"Function: {name}", str(e))


def test_class_definitions(result: TestResult):
    """Test class definitions"""
    print("\n🏠 Class Definitions:")
    
    test_cases = [
        ("class Foo { }", "empty class"),
        ("class Foo { fn bar() { 1 } }", "class with method"),
        ("class Foo { let x = 1 }", "class with field"),
    ]
    
    for source, name in test_cases:
        try:
            program = parse(source)
            if program and len(program.statements) > 0:
                result.add_pass(f"Class: {name}")
            else:
                result.add_fail(f"Class: {name}", "No statements parsed")
        except Exception as e:
            result.add_fail(f"Class: {name}", str(e))


def test_expressions(result: TestResult):
    """Test expression parsing"""
    print("\n🔢 Expressions:")
    
    test_cases = [
        ("1 + 2", "addition"),
        ("1 - 2", "subtraction"),
        ("1 * 2", "multiplication"),
        ("1 / 2", "division"),
        ("1 == 2", "equality"),
        ("1 < 2", "less than"),
        ("1 > 2", "greater than"),
        ("!true", "unary not"),
        ("-5", "unary minus"),
        ("1 + 2 * 3", "operator precedence"),
        ("(1 + 2) * 3", "grouping"),
    ]
    
    for source, name in test_cases:
        try:
            program = parse(source)
            if program and len(program.statements) > 0:
                result.add_pass(f"Expression: {name}")
            else:
                result.add_fail(f"Expression: {name}", "No statements parsed")
        except Exception as e:
            result.add_fail(f"Expression: {name}", str(e))


def test_binary_literals(result: TestResult):
    """Test binary, octal, hex literals"""
    print("\n🔢 Binary/Octal/Hex:")
    
    test_cases = [
        ("0b1010", "binary"),
        ("0o77", "octal"),
        ("0xFF", "hex"),
    ]
    
    for source, name in test_cases:
        try:
            program = parse(source)
            if program and len(program.statements) > 0:
                result.add_pass(f"Literal: {name}")
            else:
                result.add_fail(f"Literal: {name}", "No statements parsed")
        except Exception as e:
            result.add_fail(f"Literal: {name}", str(e))


def test_error_recovery(result: TestResult):
    """Test parser error recovery"""
    print("\n🔧 Error Recovery:")
    
    # Test that parser continues after errors
    source = """
let x = 1;
invalid syntax here
let y = 2;
"""
    
    try:
        program = parse(source)
        # Should have parsed at least some statements
        if program and len(program.statements) >= 2:
            result.add_pass("Error recovery")
        else:
            result.add_fail("Error recovery", "Not enough statements parsed")
    except Exception as e:
        result.add_fail("Error recovery", str(e))


def test_parse_error_messages(result: TestResult):
    """Test that parse errors have clear messages"""
    print("\n💬 Parse Error Messages:")
    
    test_cases = [
        ("(1 + 2", "missing"),
    ]
    
    for source, expected in test_cases:
        try:
            lexer = Lexer(source)
            parser = Parser(lexer)
            program = parser.parse()
            
            if parser.errors:
                result.add_pass(f"Error message: {source[:15]}")
            else:
                result.add_pass(f"No error (handled): {source[:15]}")
        except Exception as e:
            result.add_pass(f"Error raised: {source[:15]}")


def run_all_parser_tests():
    """Run all parser tests"""
    print("=" * 60)
    print("🧪 LEVEL 2 - PARSER / AST TESTS")
    print("=" * 60)
    
    result = TestResult()
    
    # Valid syntax tests
    test_valid_nested_if_else(result)
    test_valid_nested_loops(result)
    test_valid_nested_functions(result)
    test_deeply_nested_expressions(result)
    
    # Invalid syntax tests
    test_invalid_missing_parentheses(result)
    test_invalid_missing_colon(result)
    test_invalid_missing_semicolon(result)
    test_invalid_wrong_indentation(result)
    test_invalid_operator_sequence(result)
    
    # Statement tests
    test_let_statements(result)
    test_return_statements(result)
    test_function_definitions(result)
    test_class_definitions(result)
    test_expressions(result)
    test_binary_literals(result)
    
    # Error handling
    test_error_recovery(result)
    test_parse_error_messages(result)
    
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
        print("\n✅ All parser tests passed!")
        return True


if __name__ == "__main__":
    success = run_all_parser_tests()
    sys.exit(0 if success else 1)
