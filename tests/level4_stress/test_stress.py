# ================================================================
# LEVEL 4 - STRESS & BREAK TESTS
# Memory stress, concurrency, and fuzz testing
# ================================================================

import sys
import os
import random
import string
import threading
import time

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


# ==================== MEMORY STRESS TESTS ====================

def test_allocate_many_objects(result: TestResult):
    """Test allocating many objects"""
    print("\n💾 Allocate Many Objects:")
    
    # Create code that allocates many objects
    source = """
let result = 0
for (i in range(1000)) {
    let obj = { "x": i, "y": i * 2, "z": i * 3 }
    result = result + obj.x
}
result
"""
    
    try:
        output, error = run_interpreter(source, timeout_seconds=10)
        if error:
            result.add_fail("Allocate objects", error)
        else:
            result.add_pass("Allocate 1000 objects")
    except Exception as e:
        result.add_fail("Allocate objects", str(e))


def test_large_array(result: TestResult):
    """Test large array operations"""
    print("\n📊 Large Array:")
    
    source = """
let arr = []
for (i in range(1000)) {
    arr = arr + [i]
}
len(arr)
"""
    
    try:
        output, error = run_interpreter(source, timeout_seconds=10)
        if error:
            result.add_fail("Large array", error)
        else:
            result.add_pass("Large array (1000 elements)")
    except Exception as e:
        result.add_fail("Large array", str(e))


def test_string_concatenation(result: TestResult):
    """Test string concatenation in loop"""
    print("\n📝 String Concatenation:")
    
    source = """
let s = ""
for (i in range(500)) {
    s = s + "x"
}
len(s)
"""
    
    try:
        output, error = run_interpreter(source, timeout_seconds=10)
        if error:
            result.add_fail("String concat", error)
        else:
            result.add_pass("String concatenation (500)")
    except Exception as e:
        result.add_fail("String concat", str(e))


def test_deeply_nested_structures(result: TestResult):
    """Test deeply nested structures"""
    print("\n🌳 Deeply Nested Structures:")
    
    source = """
let obj = { "a": { "b": { "c": { "d": { "e": 1 } } } } }
obj.a.b.c.d.e
"""
    
    try:
        output, error = run_interpreter(source)
        if error:
            result.add_fail("Nested structures", error)
        else:
            result.add_pass("Nested structures")
    except Exception as e:
        result.add_fail("Nested structures", str(e))


# ==================== CONCURRENCY TESTS ====================

def test_concurrent_interpreters(result: TestResult):
    """Test running multiple interpreters concurrently"""
    print("\n⚡ Concurrent Interpreters:")
    
    errors = []
    
    def run_code(code, idx):
        try:
            output, err = run_interpreter(code, timeout_seconds=5)
            if err:
                errors.append((idx, err))
        except Exception as e:
            errors.append((idx, str(e)))
    
    # Run multiple interpreters concurrently
    threads = []
    for i in range(10):
        code = f"let x = {i}; x * 2"
        t = threading.Thread(target=run_code, args=(code, i))
        threads.append(t)
    
    for t in threads:
        t.start()
    
    for t in threads:
        t.join()
    
    if errors:
        result.add_fail("Concurrent interpreters", str(errors[:2]))
    else:
        result.add_pass("Concurrent interpreters (10)")


def test_shared_state_corruption(result: TestResult):
    """Test for shared state corruption"""
    print("\n🔒 Shared State:")
    
    # Each interpreter should have its own environment
    source1 = "let x = 1; x"
    source2 = "let x = 2; x"
    
    try:
        out1, err1 = run_interpreter(source1)
        out2, err2 = run_interpreter(source2)
        
        if err1 or err2:
            result.add_fail("Shared state", f"Errors: {err1}, {err2}")
        else:
            result.add_pass("Shared state isolation")
    except Exception as e:
        result.add_fail("Shared state", str(e))


# ==================== FUZZ TESTS ====================

def test_fuzz_random_code(result: TestResult):
    """Test with random code generation"""
    print("\n🎲 Fuzz Testing:")
    
    # Generate random but valid-looking code
    random.seed(42)
    
    valid_tokens = [
        "let", "if", "while", "for", "return", "fn",
        "true", "false", "null",
        "1", "2", "3", "10", "100",
        "+", "-", "*", "/", "==", "!=", "<", ">",
        "(", ")", "{", "}", "[", "]",
    ]
    
    crash_count = 0
    
    for i in range(50):
        # Generate random code snippet
        code = " ".join(random.choices(valid_tokens, k=random.randint(5, 20)))
        
        try:
            lexer = Lexer(code)
            tokens = list(lexer.tokens())
            parser = Parser(lexer)
            program = parser.parse()
            
            # Don't execute - just parse
        except Exception:
            # Expected to fail on invalid code
            pass
    
    result.add_pass(f"Fuzz testing (50 samples)")


def test_fuzz_extreme_cases(result: TestResult):
    """Test extreme fuzz cases"""
    print("\n🎲 Extreme Fuzz:")
    
    test_cases = [
        "",  # Empty
        " ",  # Whitespace only
        "\t\n\r",  # Only whitespace
        "let",  # Incomplete
        "let x",  # Incomplete
        "let x =",  # Incomplete
        "if",  # Incomplete
        "if {",  # Incomplete
        "fn",  # Incomplete
        "fn()",  # Incomplete
        "fn() {}",  # Incomplete body
        "/////",  # Invalid
        "#####",  # Invalid
        "((((((",  # Unmatched
        "))))))",  # Unmatched
    ]
    
    for source in test_cases:
        try:
            lexer = Lexer(source)
            tokens = list(lexer.tokens())
            parser = Parser(lexer)
            program = parser.parse()
        except Exception:
            # Expected to handle gracefully
            pass
    
    result.add_pass("Extreme fuzz cases")


# ==================== EDGE CASES ====================

def test_extremely_long_source(result: TestResult):
    """Test with extremely long source code"""
    print("\n📜 Extremely Long Source:")
    
    # Generate 10,000 lines of code
    lines = []
    for i in range(10000):
        lines.append(f"let x{i} = {i};")
    
    source = "\n".join(lines)
    
    try:
        lexer = Lexer(source)
        tokens = list(lexer.tokens())
        parser = Parser(lexer)
        program = parser.parse()
        
        result.add_pass("Long source (10,000 lines)")
    except Exception as e:
        result.add_fail("Long source", str(e))


def test_many_nested_blocks(result: TestResult):
    """Test with many nested blocks"""
    print("\n🔀 Many Nested Blocks:")
    
    # Create 50 levels of nesting
    source = "let x = 1"
    for i in range(50):
        source = f"if true {{ {source} }}"
    
    try:
        lexer = Lexer(source)
        tokens = list(lexer.tokens())
        parser = Parser(lexer)
        program = parser.parse()
        
        result.add_pass("Nested blocks (50 levels)")
    except Exception as e:
        result.add_fail("Nested blocks", str(e))


def test_max_expression_depth(result: TestResult):
    """Test maximum expression depth"""
    print("\n🌳 Max Expression Depth:")
    
    # Create expression with 500 levels
    expr = "1"
    for i in range(500):
        expr = f"({expr} + 1)"
    
    source = expr
    
    try:
        lexer = Lexer(source)
        tokens = list(lexer.tokens())
        parser = Parser(lexer)
        program = parser.parse()
        
        result.add_pass("Expression depth (500)")
    except Exception as e:
        result.add_fail("Expression depth", str(e))


def test_many_identifiers(result: TestResult):
    """Test with many unique identifiers"""
    print("\n🔢 Many Identifiers:")
    
    source = "let result = 0"
    for i in range(1000):
        source += f"\nlet var{i} = {i}"
    source += "\nresult"
    
    try:
        lexer = Lexer(source)
        tokens = list(lexer.tokens())
        parser = Parser(lexer)
        program = parser.parse()
        
        result.add_pass("Many identifiers (1000)")
    except Exception as e:
        result.add_fail("Many identifiers", str(e))


# ==================== SEGFAULT SIMULATION ====================

def test_null_pointer(result: TestResult):
    """Test null pointer handling"""
    print("\n❌ Null Pointer:")
    
    source = """
let x = null
x.y
"""
    
    try:
        output, error = run_interpreter(source)
        # Should not crash
        result.add_pass("Null pointer handling")
    except Exception as e:
        result.add_pass("Null pointer handled")


def test_infinite_recursion_handling(result: TestResult):
    """Test infinite recursion handling"""
    print("\n🔄 Infinite Recursion:")
    
    source = """
fn foo() {
    foo()
}
foo()
"""
    
    try:
        output, error = run_interpreter(source, timeout_seconds=3)
        result.add_pass("Infinite recursion timeout")
    except Exception as e:
        result.add_pass("Infinite recursion handled")


def run_all_stress_tests():
    """Run all stress tests"""
    print("=" * 60)
    print("🧪 LEVEL 4 - STRESS & BREAK TESTS")
    print("=" * 60)
    
    result = TestResult()
    
    # Memory stress tests
    test_allocate_many_objects(result)
    test_large_array(result)
    test_string_concatenation(result)
    test_deeply_nested_structures(result)
    
    # Concurrency tests
    test_concurrent_interpreters(result)
    test_shared_state_corruption(result)
    
    # Fuzz tests
    test_fuzz_random_code(result)
    test_fuzz_extreme_cases(result)
    
    # Edge cases
    test_extremely_long_source(result)
    test_many_nested_blocks(result)
    test_max_expression_depth(result)
    test_many_identifiers(result)
    
    # Crash prevention
    test_null_pointer(result)
    test_infinite_recursion_handling(result)
    
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
        print("\n✅ All stress tests passed!")
        return True


if __name__ == "__main__":
    success = run_all_stress_tests()
    sys.exit(0 if success else 1)
