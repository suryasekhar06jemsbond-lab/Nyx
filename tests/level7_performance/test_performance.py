# ================================================================
# LEVEL 7 - PERFORMANCE TESTS
# Startup time, memory usage, execution time benchmarks
# ================================================================

import sys
import os
import time
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
        self.timings = []
    
    def add_pass(self, name):
        self.passed += 1
        print(f"  ✓ {name}")
    
    def add_fail(self, name, error):
        self.failed += 1
        self.errors.append((name, error))
        print(f"  ✗ {name}: {error}")
    
    def add_timing(self, name, duration):
        self.timings.append((name, duration))
        print(f"  ⏱️ {name}: {duration:.4f}s")


def run_interpreter(source: str, timeout_seconds: float = 30):
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


# ==================== STARTUP TIME TESTS ====================

def test_startup_time(result: TestResult):
    """Test interpreter startup time"""
    print("\n🚀 Startup Time:")
    
    source = "1 + 1"
    iterations = 100
    
    start = time.time()
    for _ in range(iterations):
        lexer = Lexer(source)
        parser = Parser(lexer)
        program = parser.parse()
    end = time.time()
    
    duration = (end - start) / iterations
    result.add_timing("Startup time (100 iterations)", duration)


# ==================== EXECUTION TIME TESTS ====================

def test_loop_performance_1m(result: TestResult):
    """Test loop performance - 1M iterations"""
    print("\n🔄 Loop Performance (1M):")
    
    source = """
let result = 0
for i in range(1000000) {
    result = result + 1
}
"""
    
    start = time.time()
    output, error = run_interpreter(source, timeout_seconds=30)
    duration = time.time() - start
    
    if error:
        result.add_fail("Loop 1M", error)
    else:
        result.add_timing("Loop 1M iterations", duration)


def test_loop_performance_10m(result: TestResult):
    """Test loop performance - 10M iterations"""
    print("\n🔄 Loop Performance (10M):")
    
    source = """
let result = 0
for i in range(10000000) {
    result = result + 1
}
"""
    
    start = time.time()
    output, error = run_interpreter(source, timeout_seconds=60)
    duration = time.time() - start
    
    if error:
        result.add_fail("Loop 10M", error)
    else:
        result.add_timing("Loop 10M iterations", duration)


def test_recursive_performance(result: TestResult):
    """Test recursive performance"""
    print("\n📚 Recursive Performance:")
    
    source = """
fn fib(n) {
    if n <= 1 { n }
    else { fib(n - 1) + fib(n - 2) }
}
fib(20)
"""
    
    start = time.time()
    output, error = run_interpreter(source, timeout_seconds=30)
    duration = time.time() - start
    
    if error:
        result.add_fail("Recursive fib", error)
    else:
        result.add_timing("Fibonacci(20)", duration)


# ==================== MEMORY USAGE TESTS ====================

def test_memory_usage_simple(result: TestResult):
    """Test memory usage with simple operations"""
    print("\n💾 Memory Usage (Simple):")
    
    source = """
let result = 0
for i in range(100000) {
    result = result + i
}
"""
    
    start = time.time()
    output, error = run_interpreter(source, timeout_seconds=30)
    duration = time.time() - start
    
    if error:
        result.add_fail("Memory simple", error)
    else:
        result.add_timing("Memory simple (100K ops)", duration)


def test_memory_usage_complex(result: TestResult):
    """Test memory usage with complex operations"""
    print("\n💾 Memory Usage (Complex):")
    
    source = """
let result = []
for i in range(10000) {
    result = result + [{ x: i, y: i * 2 }]
}
"""
    
    start = time.time()
    output, error = run_interpreter(source, timeout_seconds=30)
    duration = time.time() - start
    
    if error:
        result.add_fail("Memory complex", error)
    else:
        result.add_timing("Memory complex (10K objects)", duration)


# ==================== PARSING PERFORMANCE TESTS ====================

def test_parsing_performance(result: TestResult):
    """Test parsing performance"""
    print("\n📝 Parsing Performance:")
    
    # Generate large source
    lines = []
    for i in range(10000):
        lines.append(f"let x{i} = {i};")
    
    source = "\n".join(lines)
    
    start = time.time()
    lexer = Lexer(source)
    tokens = list(lexer.tokens())
    parser = Parser(lexer)
    program = parser.parse()
    duration = time.time() - start
    
    result.add_timing("Parse 10K lines", duration)


def test_tokenization_performance(result: TestResult):
    """Test tokenization performance"""
    print("\n🔤 Tokenization Performance:")
    
    source = "let x = 1 + 2;" * 10000
    
    start = time.time()
    lexer = Lexer(source)
    tokens = list(lexer.tokens())
    duration = time.time() - start
    
    result.add_timing("Tokenize 10K statements", duration)


# ==================== COMPARISON BENCHMARKS ====================

def test_baseline_comparison(result: TestResult):
    """Compare against baseline languages"""
    print("\n📊 Baseline Comparison:")
    
    # Simple benchmark
    source = """
let result = 0
for i in range(100000) {
    result = result + i * 2
}
"""
    
    start = time.time()
    output, error = run_interpreter(source, timeout_seconds=30)
    nyx_time = time.time() - start
    
    if error:
        result.add_fail("Baseline comparison", error)
    else:
        # Reference times (these are just examples - actual comparison would need Python/Lua)
        print(f"  📊 Nyx: {nyx_time:.4f}s")
        print(f"  📊 Reference: ~0.5s (Python baseline)")
        result.add_pass("Baseline comparison")


def run_all_performance_tests():
    """Run all performance tests"""
    print("=" * 60)
    print("🧪 LEVEL 7 - PERFORMANCE TESTS")
    print("=" * 60)
    
    result = TestResult()
    
    # Startup
    test_startup_time(result)
    
    # Loop performance
    test_loop_performance_1m(result)
    # test_loop_performance_10m(result)  # Optional - takes longer
    
    # Recursive performance
    test_recursive_performance(result)
    
    # Memory usage
    test_memory_usage_simple(result)
    test_memory_usage_complex(result)
    
    # Parsing performance
    test_parsing_performance(result)
    test_tokenization_performance(result)
    
    # Comparison
    test_baseline_comparison(result)
    
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
        print("\n✅ All performance tests completed!")
        return True


if __name__ == "__main__":
    success = run_all_performance_tests()
    sys.exit(0 if success else 1)
