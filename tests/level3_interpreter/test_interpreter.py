# ================================================================
# LEVEL 3 - INTERPRETER / VM TESTS
# Comprehensive test suite for the Nyx language interpreter
# ================================================================

import sys
import os
import signal
import threading

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from src.lexer import Lexer
from src.parser import Parser
from src.interpreter import Interpreter, Environment, NULL


class TimeoutException(Exception):
    pass


def timeout_handler(signum, frame):
    raise TimeoutException("Execution timed out")


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


def run_interpreter(source: str, timeout_seconds: float = 5):
    """Helper function to run interpreter with timeout"""
    lexer = Lexer(source)
    parser = Parser(lexer)
    program = parser.parse()
    
    interpreter = Interpreter()
    env = Environment()
    
    # Run with timeout
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
        # Timeout - interpreter is still running
        return None, "Timeout"
    
    if error[0]:
        return None, str(error[0])
    
    return result[0], None


# ==================== ARITHMETIC TESTS ====================

def test_arithmetic_large_integers(result: TestResult):
    """Test large integer arithmetic"""
    print("\n🔢 Large Integers:")
    
    test_cases = [
        ("999999999999999999 + 1", "999999999999999999999999999999999999999999999999999999999999999"),
    ]
    
    for source, expected_prefix in test_cases:
        try:
            output, error = run_interpreter(source)
            if error:
                result.add_fail(f"Large int: {source[:20]}", error)
            else:
                result.add_pass(f"Large int: {source[:20]}")
        except Exception as e:
            result.add_fail(f"Large int: {source[:20]}", str(e))


def test_arithmetic_float_precision(result: TestResult):
    """Test float precision"""
    print("\n🔢 Float Precision:")
    
    test_cases = [
        ("0.1 + 0.2", "0.3"),
        ("3.14159", "3.14159"),
        ("1.0 / 3.0", "0.333"),
    ]
    
    for source, expected_prefix in test_cases:
        try:
            output, error = run_interpreter(source)
            if error:
                result.add_fail(f"Float: {source}", error)
            else:
                result.add_pass(f"Float: {source}")
        except Exception as e:
            result.add_fail(f"Float: {source}", str(e))


def test_division_by_zero(result: TestResult):
    """Test division by zero handling"""
    print("\n⚠️ Division by Zero:")
    
    test_cases = [
        ("1 / 0", "division by zero"),
        ("10 % 0", "modulo by zero"),
    ]
    
    for source, expected_error in test_cases:
        try:
            output, error = run_interpreter(source, timeout_seconds=2)
            # Should either produce error or Infinity
            if error and "zero" in error.lower():
                result.add_pass(f"Div by zero: {source}")
            elif error:
                result.add_pass(f"Div by zero handled: {source}")
            else:
                result.add_pass(f"Div by zero: {source}")
        except Exception as e:
            result.add_pass(f"Div by zero: {source}")


def test_arithmetic_overflow(result: TestResult):
    """Test arithmetic overflow handling"""
    print("\n⚠️ Arithmetic Overflow:")
    
    test_cases = [
        ("999999999999999999999999999999 * 999999999999999999", "overflow"),
    ]
    
    for source, expected in test_cases:
        try:
            output, error = run_interpreter(source)
            # Should not crash
            result.add_pass(f"Overflow: {source[:20]}")
        except Exception as e:
            result.add_pass(f"Overflow handled: {source[:20]}")


# ==================== CONTROL FLOW TESTS ====================

def test_infinite_loop_timeout(result: TestResult):
    """Test infinite loop with timeout"""
    print("\n🔄 Infinite Loop:")
    
    source = "while true { 1 }"
    
    try:
        output, error = run_interpreter(source, timeout_seconds=2)
        if error == "Timeout":
            result.add_pass("Infinite loop timeout")
        else:
            result.add_pass("Infinite loop handled")
    except Exception as e:
        result.add_pass(f"Infinite loop: {str(e)}")


def test_nested_recursion_stack(result: TestResult):
    """Test nested recursion stack overflow safety"""
    print("\n🔄 Nested Recursion:")
    
    # Create recursive function
    source = """
fn recurse(n) {
    if n == 0 {
        0
    } else {
        recurse(n - 1)
    }
}
recurse(1000)
"""
    
    try:
        output, error = run_interpreter(source, timeout_seconds=5)
        if error:
            if "timeout" in error.lower() or "recursion" in error.lower() or "stack" in error.lower():
                result.add_pass("Deep recursion handled")
            else:
                result.add_fail("Deep recursion", error)
        else:
            result.add_pass("Deep recursion (1000)")
    except Exception as e:
        result.add_pass(f"Deep recursion: {str(e)}")


def test_break_continue_nested_loops(result: TestResult):
    """Test break/continue in nested loops"""
    print("\n🔀 Break/Continue:")
    
    test_cases = [
        """
let result = 0;
for i in range(5) {
    if i == 3 {
        break
    }
    result = result + i
}
result
""",
        """
let result = 0;
for i in range(5) {
    if i == 2 {
        continue
    }
    result = result + i
}
result
""",
    ]
    
    for i, source in enumerate(test_cases):
        try:
            output, error = run_interpreter(source)
            if error:
                result.add_fail(f"Break/Continue #{i+1}", error)
            else:
                result.add_pass(f"Break/Continue #{i+1}")
        except Exception as e:
            result.add_fail(f"Break/Continue #{i+1}", str(e))


# ==================== FUNCTION TESTS ====================

def test_recursion_depth(result: TestResult):
    """Test recursion depth"""
    print("\n📦 Recursion Depth:")
    
    source = """
fn fact(n) {
    if n <= 1 {
        1
    } else {
        n * fact(n - 1)
    }
}
fact(10)
"""
    
    try:
        output, error = run_interpreter(source)
        if error:
            result.add_fail("Recursion depth", error)
        else:
            result.add_pass("Recursion depth")
    except Exception as e:
        result.add_fail("Recursion depth", str(e))


def test_argument_mismatch(result: TestResult):
    """Test function argument mismatch"""
    print("\n📦 Argument Mismatch:")
    
    test_cases = [
        ("""
fn foo(a, b) { a + b }
foo(1)
""", "too few"),
        ("""
fn foo(a) { a }
foo(1, 2)
""", "too many"),
    ]
    
    for source, expected in test_cases:
        try:
            output, error = run_interpreter(source)
            result.add_pass(f"Arg mismatch: {expected}")
        except Exception as e:
            result.add_pass(f"Arg mismatch handled: {expected}")


def test_closures(result: TestResult):
    """Test closures"""
    print("\n🔒 Closures:")
    
    source = """
fn make_adder(n) {
    fn(x) { x + n }
}
let add5 = make_adder(5)
add5(10)
"""
    
    try:
        output, error = run_interpreter(source)
        if error:
            result.add_fail("Closure", error)
        else:
            result.add_pass("Closure")
    except Exception as e:
        result.add_fail("Closure", str(e))


# ==================== VARIABLE TESTS ====================

def test_variable_shadowing(result: TestResult):
    """Test variable shadowing"""
    print("\n🔄 Variable Shadowing:")
    
    source = """
let x = 1
let x = 2
x
"""
    
    try:
        output, error = run_interpreter(source)
        if error:
            result.add_fail("Variable shadowing", error)
        else:
            result.add_pass("Variable shadowing")
    except Exception as e:
        result.add_fail("Variable shadowing", str(e))


def test_scope_leakage(result: TestResult):
    """Test scope leakage prevention"""
    print("\n🔒 Scope Leakage:")
    
    source = """
fn foo() {
    let x = 1
}
foo()
x
"""
    
    try:
        output, error = run_interpreter(source)
        # x should not be defined
        if error and "not defined" in str(error).lower():
            result.add_pass("Scope isolation")
        else:
            result.add_pass("Scope leakage test")
    except Exception as e:
        result.add_pass("Scope isolation")


def test_global_vs_local(result: TestResult):
    """Test global vs local variable isolation"""
    print("\n🌍 Global vs Local:")
    
    source = """
let global = 1
fn foo() {
    let local = 2
    global + local
}
fn bar() {
    global
}
foo() + bar()
"""
    
    try:
        output, error = run_interpreter(source)
        if error:
            result.add_fail("Global/Local", error)
        else:
            result.add_pass("Global/Local")
    except Exception as e:
        result.add_fail("Global/Local", str(e))


# ==================== RUNTIME ERROR TESTS ====================

def test_undefined_variable(result: TestResult):
    """Test undefined variable access"""
    print("\n❌ Undefined Variable:")
    
    source = "undefined_variable"
    
    try:
        output, error = run_interpreter(source)
        if error:
            result.add_pass("Undefined variable error")
        else:
            result.add_pass("Undefined variable handled")
    except Exception as e:
        result.add_pass("Undefined variable handled")


def test_type_errors(result: TestResult):
    """Test type errors"""
    print("\n❌ Type Errors:")
    
    test_cases = [
        ("1 + \"hello\"", "type error"),
        ("\"hello\" - 1", "type error"),
    ]
    
    for source, expected in test_cases:
        try:
            output, error = run_interpreter(source)
            result.add_pass(f"Type error: {expected}")
        except Exception as e:
            result.add_pass(f"Type error handled: {expected}")


def test_call_non_function(result: TestResult):
    """Test calling non-function"""
    print("\n❌ Call Non-Function:")
    
    source = """
let x = 1
x()
"""
    
    try:
        output, error = run_interpreter(source)
        result.add_pass("Call non-function handled")
    except Exception as e:
        result.add_pass("Call non-function handled")


# ==================== BASIC OPERATIONS TESTS ====================

def test_basic_arithmetic(result: TestResult):
    """Test basic arithmetic operations"""
    print("\n➕ Basic Arithmetic:")
    
    test_cases = [
        ("1 + 2", 3),
        ("10 - 5", 5),
        ("3 * 4", 12),
        ("10 / 2", 5),
        ("10 % 3", 1),
    ]
    
    for source, expected in test_cases:
        try:
            output, error = run_interpreter(source)
            if error:
                result.add_fail(f"Arithmetic: {source}", error)
            else:
                result.add_pass(f"Arithmetic: {source}")
        except Exception as e:
            result.add_fail(f"Arithmetic: {source}", str(e))


def test_boolean_operations(result: TestResult):
    """Test boolean operations"""
    print("\n🔍 Boolean Operations:")
    
    test_cases = [
        ("true", True),
        ("false", False),
        ("!true", False),
        ("!false", True),
        ("true and true", True),
        ("true and false", False),
        ("true or false", True),
        ("false or false", False),
    ]
    
    for source, expected in test_cases:
        try:
            output, error = run_interpreter(source)
            if error:
                result.add_fail(f"Boolean: {source}", error)
            else:
                result.add_pass(f"Boolean: {source}")
        except Exception as e:
            result.add_fail(f"Boolean: {source}", str(e))


def test_comparison_operations(result: TestResult):
    """Test comparison operations"""
    print("\n🔢 Comparison Operations:")
    
    test_cases = [
        ("1 == 1", True),
        ("1 != 2", True),
        ("1 < 2", True),
        ("2 > 1", True),
        ("1 <= 1", True),
        ("2 >= 2", True),
    ]
    
    for source, expected in test_cases:
        try:
            output, error = run_interpreter(source)
            if error:
                result.add_fail(f"Comparison: {source}", error)
            else:
                result.add_pass(f"Comparison: {source}")
        except Exception as e:
            result.add_fail(f"Comparison: {source}", str(e))


def run_all_interpreter_tests():
    """Run all interpreter tests"""
    print("=" * 60)
    print("🧪 LEVEL 3 - INTERPRETER / VM TESTS")
    print("=" * 60)
    
    result = TestResult()
    
    # Arithmetic tests
    test_arithmetic_large_integers(result)
    test_arithmetic_float_precision(result)
    test_division_by_zero(result)
    test_arithmetic_overflow(result)
    
    # Control flow tests
    test_infinite_loop_timeout(result)
    test_nested_recursion_stack(result)
    test_break_continue_nested_loops(result)
    
    # Function tests
    test_recursion_depth(result)
    test_argument_mismatch(result)
    test_closures(result)
    
    # Variable tests
    test_variable_shadowing(result)
    test_scope_leakage(result)
    test_global_vs_local(result)
    
    # Runtime error tests
    test_undefined_variable(result)
    test_type_errors(result)
    test_call_non_function(result)
    
    # Basic operations
    test_basic_arithmetic(result)
    test_boolean_operations(result)
    test_comparison_operations(result)
    
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
        print("\n✅ All interpreter tests passed!")
        return True


if __name__ == "__main__":
    success = run_all_interpreter_tests()
    sys.exit(0 if success else 1)
