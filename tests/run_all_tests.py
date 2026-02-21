# ================================================================
# NYX LANGUAGE COMPREHENSIVE TEST SUITE
# Main test runner for all 10 levels
# ================================================================

import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def run_level_1():
    """Run Level 1 - Lexer Tests"""
    print("\n" + "=" * 70)
    print("LEVEL 1 - LEXER TESTS (Tokenization)")
    print("=" * 70)
    from tests.level1_lexer.test_lexer import run_all_lexer_tests
    return run_all_lexer_tests()


def run_level_2():
    """Run Level 2 - Parser Tests"""
    print("\n" + "=" * 70)
    print("LEVEL 2 - PARSER / AST TESTS")
    print("=" * 70)
    from tests.level2_parser.test_parser import run_all_parser_tests
    return run_all_parser_tests()


def run_level_3():
    """Run Level 3 - Interpreter Tests"""
    print("\n" + "=" * 70)
    print("LEVEL 3 - INTERPRETER / VM TESTS")
    print("=" * 70)
    from tests.level3_interpreter.test_interpreter import run_all_interpreter_tests
    return run_all_interpreter_tests()


def run_level_4():
    """Run Level 4 - Stress Tests"""
    print("\n" + "=" * 70)
    print("LEVEL 4 - STRESS & BREAK TESTS")
    print("=" * 70)
    from tests.level4_stress.test_stress import run_all_stress_tests
    return run_all_stress_tests()


def run_level_5():
    """Run Level 5 - Standard Library Tests"""
    print("\n" + "=" * 70)
    print("LEVEL 5 - STANDARD LIBRARY TESTS")
    print("=" * 70)
    from tests.level5_stdlib.test_stdlib import run_all_stdlib_tests
    return run_all_stdlib_tests()


def run_level_6():
    """Run Level 6 - Security Tests"""
    print("\n" + "=" * 70)
    print("LEVEL 6 - SECURITY TESTS")
    print("=" * 70)
    from tests.level6_security.test_security import run_all_security_tests
    return run_all_security_tests()


def run_level_7():
    """Run Level 7 - Performance Tests"""
    print("\n" + "=" * 70)
    print("LEVEL 7 - PERFORMANCE TESTS")
    print("=" * 70)
    from tests.level7_performance.test_performance import run_all_performance_tests
    return run_all_performance_tests()


def run_level_8():
    """Run Level 8 - Spec Compliance Tests"""
    print("\n" + "=" * 70)
    print("LEVEL 8 - SPEC COMPLIANCE TESTS")
    print("=" * 70)
    from tests.level8_compliance.test_compliance import run_all_compliance_tests
    return run_all_compliance_tests()


def run_level_9():
    """Run Level 9 - Consistency Tests"""
    print("\n" + "=" * 70)
    print("LEVEL 9 - SELF CONSISTENCY TESTS")
    print("=" * 70)
    from tests.level9_consistency.test_consistency import run_all_consistency_tests
    return run_all_consistency_tests()


def run_level_10():
    """Run Level 10 - Real World Tests"""
    print("\n" + "=" * 70)
    print("LEVEL 10 - REAL WORLD PROGRAM TESTS")
    print("=" * 70)
    from tests.level10_realworld.test_realworld import run_all_realworld_tests
    return run_all_realworld_tests()


def main():
    """Run all test levels"""
    print("\n" + "=" * 70)
    print("NYX LANGUAGE COMPREHENSIVE TEST SUITE")
    print("=" * 70)
    print("Running all 10 levels of tests...")
    
    results = []
    levels = [
        ("Level 1 - Lexer", run_level_1),
        ("Level 2 - Parser", run_level_2),
        ("Level 3 - Interpreter", run_level_3),
        ("Level 4 - Stress", run_level_4),
        ("Level 5 - Stdlib", run_level_5),
        ("Level 6 - Security", run_level_6),
        ("Level 7 - Performance", run_level_7),
        ("Level 8 - Compliance", run_level_8),
        ("Level 9 - Consistency", run_level_9),
        ("Level 10 - Real World", run_level_10),
    ]
    
    for name, test_func in levels:
        try:
            success = test_func()
            results.append((name, success))
        except Exception as e:
            print(f"\nERROR: {name} CRASHED: {e}")
            results.append((name, False))
    
    # Summary
    print("\n" + "=" * 70)
    print("FINAL TEST SUMMARY")
    print("=" * 70)
    
    passed = sum(1 for _, s in results if s)
    failed = sum(1 for _, s in results if not s)
    
    for name, success in results:
        status = "PASS" if success else "FAIL"
        print(f"  [{status}] - {name}")
    
    print("\n" + "=" * 70)
    print(f"Total: {passed} passed, {failed} failed out of {len(results)} levels")
    print("=" * 70)
    
    if failed == 0:
        print("\nALL TESTS PASSED!")
        return 0
    else:
        print(f"\n{failed} test level(s) failed")
        return 1


if __name__ == "__main__":
    sys.exit(main())
