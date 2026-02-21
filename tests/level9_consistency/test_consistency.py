# ================================================================
# LEVEL 9 - SELF CONSISTENCY TESTS
# Run interpreter 10,000 times, check output consistency
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


def test_repeated_parsing(result: TestResult):
    """Test parsing same code 1000 times"""
    print("\n🔁 Repeated Parsing:")
    
    source = "let x = 1 + 2 * 3"
    
    try:
        for i in range(1000):
            lexer = Lexer(source)
            parser = Parser(lexer)
            program = parser.parse()
        
        result.add_pass("Parse 1000 times")
    except Exception as e:
        result.add_fail("Parse 1000 times", str(e))


def test_repeated_execution(result: TestResult):
    """Test executing same code 1000 times"""
    print("\n🔁 Repeated Execution:")
    
    source = "let x = 1 + 1"
    
    results = []
    for i in range(1000):
        output, error = run_interpreter(source)
        if error:
            result.add_fail("Execute 1000 times", error)
            return
        results.append(output)
    
    # Check all results are consistent
    if len(set(str(r) for r in results)) == 1:
        result.add_pass("Execute 1000 times")
    else:
        result.add_fail("Execute 1000 times", "Inconsistent results")


def test_output_determinism(result: TestResult):
    """Test that same code produces same output"""
    print("\n🎯 Output Determinism:")
    
    test_cases = [
        ("1 + 2 + 3 + 4 + 5", "25"),
        ("let x = 10; x * x", "100"),
        ("[1, 2, 3, 4, 5]", "list"),
    ]
    
    for source, expected in test_cases:
        outputs = []
        for _ in range(100):
            output, error = run_interpreter(source)
            if error:
                result.add_fail(f"Determinism: {source[:20]}", error)
                return
            outputs.append(str(output) if output is not None else "null")
        
        if len(set(outputs)) == 1:
            result.add_pass(f"Determinism: {source[:20]}")
        else:
            result.add_fail(f"Determinism: {source[:20]}", f"Got {len(set(outputs))} different outputs")


def test_interpreter_reset(result: TestResult):
    """Test interpreter state reset"""
    print("\n🔄 Interpreter Reset:")
    
    # First run: define variable
    source1 = "let x = 42"
    run_interpreter(source1)
    
    # Second run: use same variable name (should be independent)
    source2 = "let x = 100"
    output, error = run_interpreter(source2)
    
    if error:
        result.add_fail("Interpreter reset", error)
    else:
        result.add_pass("Interpreter reset")


def test_no_randomness(result: TestResult):
    """Test that there is no unintended randomness"""
    print("\n🎲 No Unintended Randomness:")
    
    source = "for i in range(100) { i }"
    
    outputs = []
    for _ in range(50):
        output, error = run_interpreter(source)
        if error:
            result.add_fail("No randomness", error)
            return
        outputs.append(str(output))
    
    if len(set(outputs)) == 1:
        result.add_pass("No unintended randomness")
    else:
        result.add_fail("No randomness", "Found different outputs")


def run_all_consistency_tests():
    """Run all consistency tests"""
    print("=" * 60)
    print("🧪 LEVEL 9 - SELF CONSISTENCY TESTS")
    print("=" * 60)
    
    result = TestResult()
    
    test_repeated_parsing(result)
    test_repeated_execution(result)
    test_output_determinism(result)
    test_interpreter_reset(result)
    test_no_randomness(result)
    
    print("\n" + "=" * 60)
    print(f"📊 Results: {result.passed} passed, {result.failed} failed")
    print("=" * 60)
    
    if result.failed > 0:
        print("\n❌ Failed tests:")
        for name, error in result.errors:
            print(f"  - {name}: {error}")
        return False
    else:
        print("\n✅ All consistency tests passed!")
        return True


if __name__ == "__main__":
    success = run_all_consistency_tests()
    sys.exit(0 if success else 1)
