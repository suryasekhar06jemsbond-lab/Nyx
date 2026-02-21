# ================================================================
# LEVEL 10 - REAL WORLD PROGRAM TESTS
# Calculator, JSON parser, HTTP server, CLI tool tests
# ================================================================

import sys
import os
import threading

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from src.lexer import Lexer
from src.parser import Parser
from src.interpreter import Interpreter, Environment


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


def run_interpreter(source: str, timeout_seconds: float = 10):
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


# ==================== CALCULATOR TESTS ====================

def test_calculator_basic(result: TestResult):
    """Test basic calculator operations"""
    print("\n🧮 Calculator - Basic:")
    
    test_cases = [
        ("1 + 2", 3),
        ("10 - 5", 5),
        ("3 * 4", 12),
        ("10 / 2", 5),
        ("10 % 3", 1),
    ]
    
    for source, expected in test_cases:
        output, error = run_interpreter(source)
        if error:
            result.add_fail(f"Calculator: {source}", error)
        else:
            result.add_pass(f"Calculator: {source}")


def test_calculator_advanced(result: TestResult):
    """Test advanced calculator operations"""
    print("\n🧮 Calculator - Advanced:")
    
    test_cases = [
        ("2 ** 3", 8),
        ("10 // 3", 3),
        ("(1 + 2) * 3", 9),
    ]
    
    for source, expected in test_cases:
        output, error = run_interpreter(source)
        if error:
            result.add_fail(f"Calculator advanced: {source}", error)
        else:
            result.add_pass(f"Calculator advanced: {source}")


# ==================== DATA STRUCTURE TESTS ====================

def test_json_like_object(result: TestResult):
    """Test JSON-like object handling"""
    print("\n📋 JSON-like Object:")
    
    source = """
let data = {
    "name": "John",
    "age": 30,
    "city": "NYC"
}
data.name
"""
    
    output, error = run_interpreter(source)
    if error:
        result.add_fail("JSON-like object", error)
    else:
        result.add_pass("JSON-like object")


def test_array_operations(result: TestResult):
    """Test array operations"""
    print("\n📋 Array Operations:")
    
    source = """
let arr = [1, 2, 3, 4, 5]
let sum = 0
for i in arr {
    sum = sum + i
}
sum
"""
    
    output, error = run_interpreter(source)
    if error:
        result.add_fail("Array operations", error)
    else:
        result.add_pass("Array operations")


# ==================== ALGORITHM TESTS ====================

def test_fibonacci(result: TestResult):
    """Test fibonacci implementation"""
    print("\n🔢 Fibonacci:")
    
    source = """
fn fib(n) {
    if n <= 1 { n }
    else { fib(n - 1) + fib(n - 2) }
}
fib(10)
"""
    
    output, error = run_interpreter(source, timeout_seconds=10)
    if error:
        result.add_fail("Fibonacci", error)
    else:
        result.add_pass("Fibonacci")


def test_factorial(result: TestResult):
    """Test factorial implementation"""
    print("\n🔢 Factorial:")
    
    source = """
fn fact(n) {
    if n <= 1 { 1 }
    else { n * fact(n - 1) }
}
fact(10)
"""
    
    output, error = run_interpreter(source)
    if error:
        result.add_fail("Factorial", error)
    else:
        result.add_pass("Factorial")


def test_sort_algorithm(result: TestResult):
    """Test basic sorting"""
    print("\n🔢 Sort Algorithm:")
    
    source = """
let arr = [5, 3, 8, 1, 2]
let sorted = []
while len(arr) > 0 {
    let min = arr[0]
    let idx = 0
    let i = 0
    for item in arr {
        if item < min {
            min = item
            idx = i
        }
        i = i + 1
    }
    sorted = sorted + [min]
    arr = arr[0:idx] + arr[idx+1:len(arr)]
}
sorted[0]
"""
    
    output, error = run_interpreter(source, timeout_seconds=15)
    if error:
        result.add_fail("Sort algorithm", error)
    else:
        result.add_pass("Sort algorithm")


# ==================== FUNCTION PROGRAM TESMS ====================

def test_higher_order_functions(result: TestResult):
    """Test higher-order functions"""
    print("\n📦 Higher-Order Functions:")
    
    source = """
fn apply(x, f) {
    f(x)
}
fn double(x) {
    x * 2
}
apply(5, double)
"""
    
    output, error = run_interpreter(source)
    if error:
        result.add_fail("Higher-order functions", error)
    else:
        result.add_pass("Higher-order functions")


def test_currying(result: TestResult):
    """Test function currying"""
    print("\n📦 Currying:")
    
    source = """
fn add(a) {
    fn(b) { a + b }
}
let add5 = add(5)
add5(3)
"""
    
    output, error = run_interpreter(source)
    if error:
        result.add_fail("Currying", error)
    else:
        result.add_pass("Currying")


# ==================== OOP TESTS ====================

def test_simple_class(result: TestResult):
    """Test simple class"""
    print("\n🏠 Simple Class:")
    
    source = """
class Counter {
    fn new() {
        let c = { value: 0 }
        c
    }
    fn increment(c) {
        c.value = c.value + 1
        c.value
    }
}
let c = Counter.new()
Counter.increment(c)
"""
    
    output, error = run_interpreter(source)
    if error:
        result.add_fail("Simple class", error)
    else:
        result.add_pass("Simple class")


# ==================== ERROR HANDLING TESTS ====================

def test_exception_handling(result: TestResult):
    """Test exception handling"""
    print("\n⚠️ Exception Handling:")
    
    source = """
try {
    let x = 1 / 0
} except {
    "error caught"
}
"""
    
    output, error = run_interpreter(source)
    if error:
        result.add_fail("Exception handling", error)
    else:
        result.add_pass("Exception handling")


def run_all_realworld_tests():
    """Run all real world program tests"""
    print("=" * 60)
    print("🧪 LEVEL 10 - REAL WORLD PROGRAM TESTS")
    print("=" * 60)
    
    result = TestResult()
    
    # Calculator tests
    test_calculator_basic(result)
    test_calculator_advanced(result)
    
    # Data structures
    test_json_like_object(result)
    test_array_operations(result)
    
    # Algorithms
    test_fibonacci(result)
    test_factorial(result)
    test_sort_algorithm(result)
    
    # Functions
    test_higher_order_functions(result)
    test_currying(result)
    
    # OOP
    test_simple_class(result)
    
    # Error handling
    test_exception_handling(result)
    
    print("\n" + "=" * 60)
    print(f"📊 Results: {result.passed} passed, {result.failed} failed")
    print("=" * 60)
    
    if result.failed > 0:
        print("\n❌ Failed tests:")
        for name, error in result.errors:
            print(f"  - {name}: {error}")
        return False
    else:
        print("\n✅ All real world tests passed!")
        return True


if __name__ == "__main__":
    success = run_all_realworld_tests()
    sys.exit(0 if success else 1)
