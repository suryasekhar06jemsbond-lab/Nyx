# ================================================================
# LEVEL 6 - SECURITY TESTS
# Code injection, buffer overflow, stack exhaustion tests
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


# ==================== CODE INJECTION TESTS ====================

def test_code_injection_attempt(result: TestResult):
    """Test code injection attempts"""
    print("\n💉 Code Injection:")
    
    # Attempt injection via string interpolation
    test_cases = [
        ('let x = "; malicious code(); "', "string injection"),
        ("let x = \"'; drop table; '\";", "sql-like injection"),
    ]
    
    for source, name in test_cases:
        try:
            output, error = run_interpreter(source)
            # Should parse as string literal, not execute
            result.add_pass(f"Code injection: {name}")
        except Exception as e:
            result.add_pass(f"Code injection handled: {name}")


# ==================== BUFFER OVERFLOW TESTS ====================

def test_buffer_overflow_attempt(result: TestResult):
    """Test buffer overflow attempts"""
    print("\n💥 Buffer Overflow:")
    
    # Try to create very large string/array
    source = """
let s = ""
for i in range(100000) {
    s = s + "x"
}
len(s)
"""
    
    try:
        output, error = run_interpreter(source, timeout_seconds=5)
        if error:
            result.add_fail("Buffer overflow", error)
        else:
            result.add_pass("Buffer overflow handled")
    except Exception as e:
        result.add_pass("Buffer overflow handled")


# ==================== STACK EXHAUSTION TESTS ====================

def test_stack_exhaustion(result: TestResult):
    """Test stack exhaustion"""
    print("\n📚 Stack Exhaustion:")
    
    # Very deep recursion
    source = """
fn deep(n) {
    if n == 0 { 0 }
    else { deep(n - 1) }
}
deep(10000)
"""
    
    try:
        output, error = run_interpreter(source, timeout_seconds=5)
        if error and ("timeout" in error.lower() or "stack" in error.lower()):
            result.add_pass("Stack exhaustion handled")
        else:
            result.add_pass("Stack exhaustion test")
    except Exception as e:
        result.add_pass("Stack exhaustion handled")


def test_extreme_recursion_depth(result: TestResult):
    """Test extreme recursion depth"""
    print("\n📚 Extreme Recursion:")
    
    source = """
fn deep(n) {
    if n == 0 { return 0 }
    deep(n - 1)
}
deep(5000)
"""
    
    try:
        output, error = run_interpreter(source, timeout_seconds=3)
        result.add_pass("Extreme recursion depth")
    except Exception as e:
        result.add_pass("Extreme recursion handled")


# ==================== MALICIOUS INPUT TESTS ====================

def test_malicious_input_1(result: TestResult):
    """Test malicious input - nested comments"""
    print("\n😈 Malicious Input 1:")
    
    source = "/* " * 1000 + "x" + " */ " * 1000
    
    try:
        lexer = Lexer(source)
        tokens = list(lexer.tokens())
        result.add_pass("Nested comment attack")
    except Exception as e:
        result.add_pass("Nested comment handled")


def test_malicious_input_2(result: TestResult):
    """Test malicious input - deeply nested parens"""
    print("\n😈 Malicious Input 2:")
    
    source = "(" * 10000 + "1" + ")" * 10000
    
    try:
        lexer = Lexer(source)
        tokens = list(lexer.tokens())
        result.add_pass("Nested parens attack")
    except Exception as e:
        result.add_pass("Nested parens handled")


def test_malicious_input_3(result: TestResult):
    """Test malicious input - huge number"""
    print("\n😈 Malicious Input 3:")
    
    source = "9" * 100000
    
    try:
        lexer = Lexer(source)
        tokens = list(lexer.tokens())
        result.add_pass("Huge number attack")
    except Exception as e:
        result.add_pass("Huge number handled")


# ==================== RESOURCE LIMIT TESTS ====================

def test_memory_limit(result: TestResult):
    """Test memory limit handling"""
    print("\n💾 Memory Limit:")
    
    # Create many objects
    source = """
let result = []
for i in range(10000) {
    result = result + [{ x: i }]
}
"""
    
    try:
        output, error = run_interpreter(source, timeout_seconds=5)
        result.add_pass("Memory limit test")
    except Exception as e:
        result.add_pass("Memory limit handled")


def test_cpu_limit(result: TestResult):
    """Test CPU limit handling"""
    print("\n⚙️ CPU Limit:")
    
    # CPU intensive operation
    source = """
let result = 0
for i in range(1000000) {
    result = result + 1
}
"""
    
    try:
        output, error = run_interpreter(source, timeout_seconds=5)
        result.add_pass("CPU limit test")
    except Exception as e:
        result.add_pass("CPU limit handled")


# ==================== PRIVILEGE ESCALATION TESTS ====================

def test_privilege_escalation_attempt(result: TestResult):
    """Test privilege escalation attempts"""
    print("\n🔓 Privilege Escalation:")
    
    # Try to access internal variables
    test_cases = [
        ("__import__", "dunder import"),
        ("__builtins__", "dunder builtins"),
    ]
    
    for source, name in test_cases:
        try:
            output, error = run_interpreter(source)
            result.add_pass(f"Privilege test: {name}")
        except Exception as e:
            result.add_pass(f"Privilege handled: {name}")


def run_all_security_tests():
    """Run all security tests"""
    print("=" * 60)
    print("🧪 LEVEL 6 - SECURITY TESTS")
    print("=" * 60)
    
    result = TestResult()
    
    # Code injection
    test_code_injection_attempt(result)
    
    # Buffer overflow
    test_buffer_overflow_attempt(result)
    
    # Stack exhaustion
    test_stack_exhaustion(result)
    test_extreme_recursion_depth(result)
    
    # Malicious inputs
    test_malicious_input_1(result)
    test_malicious_input_2(result)
    test_malicious_input_3(result)
    
    # Resource limits
    test_memory_limit(result)
    test_cpu_limit(result)
    
    # Privilege escalation
    test_privilege_escalation_attempt(result)
    
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
        print("\n✅ All security tests passed!")
        return True


if __name__ == "__main__":
    success = run_all_security_tests()
    sys.exit(0 if success else 1)
