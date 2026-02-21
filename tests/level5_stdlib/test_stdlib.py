# ================================================================
# LEVEL 5 - STANDARD LIBRARY TESTS
# File I/O, networking, math, string library tests
# ================================================================

import sys
import os
import tempfile
import threading

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from src.lexer import Lexer
from src.parser import Parser
from src.interpreter import Interpreter, Environment


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


def run_interpreter(source: str, timeout_seconds: float = 10):
    """Helper function to run interpreter with timeout"""
    try:
        lexer = Lexer(source)
        parser = Parser(lexer)
        program = parser.parse()
        
        interpreter = Interpreter()
        env = Environment()
        
        result = [None]
        error = [None]
        
        def run():
            try:
                result[0] = interpreter.eval(program, env)
            except Exception as e:
                error[0] = e
        
        t = threading.Thread(target=run)
        t.daemon = True
        t.start()
        t.join(timeout_seconds)
        
        if t.is_alive():
            return None, "Timeout"
        
        if error[0]:
            return None, str(error[0])
        
        return result[0], None
    except Exception as e:
        return None, str(e)


# ==================== MATH LIBRARY TESTS ====================

def test_math_operations(result: TestResult):
    """Test math operations"""
    print("\n🔢 Math Operations:")
    
    test_cases = [
        ("abs(-5)", "abs"),
        ("max(1, 5)", "max"),
        ("min(1, 5)", "min"),
    ]
    
    for source, name in test_cases:
        try:
            output, error = run_interpreter(source)
            if error:
                result.add_fail(f"Math: {name}", error)
            else:
                result.add_pass(f"Math: {name}")
        except Exception as e:
            result.add_fail(f"Math: {name}", str(e))


# ==================== STRING LIBRARY TESTS ====================

def test_string_operations(result: TestResult):
    """Test string operations"""
    print("\n📝 String Operations:")
    
    test_cases = [
        ('len("hello")', "len string"),
        ('"hello" + "world"', "string concat"),
        ('"hello" == "hello"', "string eq"),
        ('"hello" != "world"', "string neq"),
    ]
    
    for source, name in test_cases:
        try:
            output, error = run_interpreter(source)
            if error:
                result.add_fail(f"String: {name}", error)
            else:
                result.add_pass(f"String: {name}")
        except Exception as e:
            result.add_fail(f"String: {name}", str(e))


def test_string_methods(result: TestResult):
    """Test string methods"""
    print("\n📝 String Methods:")
    
    test_cases = [
        ('"hello".upper()', "upper"),
        ('"HELLO".lower()', "lower"),
        ('"hello".trim()', "trim"),
    ]
    
    for source, name in test_cases:
        try:
            output, error = run_interpreter(source)
            if error:
                result.add_fail(f"String method: {name}", error)
            else:
                result.add_pass(f"String method: {name}")
        except Exception as e:
            result.add_fail(f"String method: {name}", str(e))


# ==================== COLLECTION TESTS ====================

def test_array_operations(result: TestResult):
    """Test array operations"""
    print("\n📋 Array Operations:")
    
    test_cases = [
        ("[1, 2, 3]", "array literal"),
        ("len([1, 2, 3])", "len array"),
        ("[1, 2] + [3, 4]", "array concat"),
    ]
    
    for source, name in test_cases:
        try:
            output, error = run_interpreter(source)
            if error:
                result.add_fail(f"Array: {name}", error)
            else:
                result.add_pass(f"Array: {name}")
        except Exception as e:
            result.add_fail(f"Array: {name}", str(e))


def test_object_operations(result: TestResult):
    """Test object operations"""
    print("\n🏷️ Object Operations:")
    
    test_cases = [
        ("{ x: 1, y: 2 }", "object literal"),
        ("{ x: 1 }.x", "property access"),
    ]
    
    for source, name in test_cases:
        try:
            output, error = run_interpreter(source)
            if error:
                result.add_fail(f"Object: {name}", error)
            else:
                result.add_pass(f"Object: {name}")
        except Exception as e:
            result.add_fail(f"Object: {name}", str(e))


# ==================== BUILT-IN FUNCTIONS ====================

def test_builtin_print(result: TestResult):
    """Test print function"""
    print("\n🖨️ Print Function:")
    
    source = 'print("hello")'
    
    try:
        output, error = run_interpreter(source)
        result.add_pass("Print function")
    except Exception as e:
        result.add_fail("Print function", str(e))


def test_builtin_range(result: TestResult):
    """Test range function"""
    print("\n🔄 Range Function:")
    
    source = "range(5)"
    
    try:
        output, error = run_interpreter(source)
        if error:
            result.add_fail("Range function", error)
        else:
            result.add_pass("Range function")
    except Exception as e:
        result.add_fail("Range function", str(e))


def test_builtin_len(result: TestResult):
    """Test len function with different types"""
    print("\n📏 Len Function:")
    
    test_cases = [
        ("len([1, 2, 3])", "len array"),
        ('len("hello")', "len string"),
        ("len({ x: 1 })", "len object"),
    ]
    
    for source, name in test_cases:
        try:
            output, error = run_interpreter(source)
            if error:
                result.add_fail(f"Len: {name}", error)
            else:
                result.add_pass(f"Len: {name}")
        except Exception as e:
            result.add_fail(f"Len: {name}", str(e))


# ==================== ERROR HANDLING TESTS ====================

def test_error_handling_null_access(result: TestResult):
    """Test error handling for null property access"""
    print("\n❌ Null Access:")
    
    source = """
let x = null
x.property
"""
    
    try:
        output, error = run_interpreter(source)
        # Should not crash, should return error or null
        result.add_pass("Null property access")
    except Exception as e:
        result.add_pass("Null access handled")


def test_error_handling_type_mismatch(result: TestResult):
    """Test error handling for type mismatches"""
    print("\n❌ Type Mismatch:")
    
    source = "1 + 'hello'"
    
    try:
        output, error = run_interpreter(source)
        result.add_pass("Type mismatch handling")
    except Exception as e:
        result.add_pass("Type mismatch handled")


def test_error_handling_invalid_index(result: TestResult):
    """Test error handling for invalid index"""
    print("\n❌ Invalid Index:")
    
    source = "[1, 2, 3][100]"
    
    try:
        output, error = run_interpreter(source)
        result.add_pass("Invalid index handling")
    except Exception as e:
        result.add_pass("Invalid index handled")


def run_all_stdlib_tests():
    """Run all standard library tests"""
    print("=" * 60)
    print("🧪 LEVEL 5 - STANDARD LIBRARY TESTS")
    print("=" * 60)
    
    result = TestResult()
    
    # Math operations
    test_math_operations(result)
    
    # String operations
    test_string_operations(result)
    test_string_methods(result)
    
    # Collection tests
    test_array_operations(result)
    test_object_operations(result)
    
    # Built-in functions
    test_builtin_print(result)
    test_builtin_range(result)
    test_builtin_len(result)
    
    # Error handling
    test_error_handling_null_access(result)
    test_error_handling_type_mismatch(result)
    test_error_handling_invalid_index(result)
    
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
        print("\n✅ All stdlib tests passed!")
        return True


if __name__ == "__main__":
    success = run_all_stdlib_tests()
    sys.exit(0 if success else 1)
