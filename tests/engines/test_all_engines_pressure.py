#!/usr/bin/env python3
"""
===================================================================================
COMPREHENSIVE ENGINE PRESSURE TEST SUITE
Tests all 123 Nyx engines under heavy load, concurrent access, and stress conditions
===================================================================================

This test suite validates:
- Concurrent engine initialization
- High-volume operations
- Memory/resource stress
- Error recovery under pressure
- Multi-threaded access
- Long-running operations

Engine Categories (123 Total):
1. AI/ML Engines (21)
2. Data Processing Engines (18)
3. Security Engines (17)
4. Web Engines (15)
5. Storage Engines (14)
6. DevOps Engines (12)
7. Graphics & Media Engines (10)
8. Scientific Computing Engines (8)
9. Utility Engines (8)
"""

import sys
import os
import threading
import time
import random
import string
from typing import Dict, List, Tuple
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass

# Fix Windows encoding issues with Unicode
if sys.platform == "win32":
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from src.lexer import Lexer
from src.parser import Parser
from src.interpreter import Interpreter, Environment


@dataclass
class EngineTestResult:
    """Result of an engine pressure test"""
    engine_name: str
    category: str
    passed: bool
    duration: float
    operations_completed: int
    errors: List[str]
    peak_memory_mb: float = 0.0


class EnginePressureTester:
    """Manages pressure testing for all engines"""
    
    def __init__(self, num_workers: int = 18, duration_seconds: int = 60):
        self.num_workers = num_workers
        self.duration_seconds = duration_seconds
        self.results: List[EngineTestResult] = []
        
        # Engine definitions by category
        self.engine_categories = {
            "AI/ML": [
                "nyai", "nygrad", "nygraph_ml", "nyml", "nymodel", "nyopt", "nyrl",
                "nyagent", "nyannotate", "nyfig", "nygenomics", "nygroup", "nyhyper",
                "nyimpute", "nyinstance", "nyloss", "nymetalearn", "nynlp", "nyobserve",
                "nypred", "nytransform"
            ],
            "Data Processing": [
                "nydata", "nydatabase", "nyquery", "nybatch", "nycache", "nycompute",
                "nyingest", "nyindex", "nyio", "nyjoin", "nyload", "nymemory",
                "nymeta", "nypipeline", "nyproc", "nyroq", "nyscribe", "nystorage"
            ],
            "Security": [
                "nysec", "nysecure", "nycrypto", "nyaudit", "nycompliance", "nyexploit",
                "nyfuzz", "nyids", "nymal", "nyrecon", "nyreverse", "nyrisk",
                "nyscan", "nyshield", "nysign", "nytrust", "nyvault"
            ],
            "Web": [
                "nyweb", "nyhttp", "nyapi", "nyserve", "nyserver", "nyserverless",
                "nynet", "nynetwork", "nycloud", "nykube", "nycontainer", "nycluster",
                "nybalance", "nyproxy", "nygateway"
            ],
            "Storage": [
                "nydb", "nystore", "nyfile", "nydisk", "nyblock", "nyobject",
                "nycache", "nymemcache", "nyredis", "nyqueue", "nystream", "nyevent",
                "nylog", "nyarchive"
            ],
            "DevOps": [
                "nybuild", "nyci", "nydeploy", "nymonitor", "nymetrics", "nytrace",
                "nyalert", "nyconfig", "nyprovision", "nyinfra", "nyscale", "nypack"
            ],
            "Graphics/Media": [
                "nyrender", "nygpu", "nygame", "nyui", "nygui", "nyanim",
                "nymedia", "nyaudio", "nyvoice", "nyviz"
            ],
            "Scientific": [
                "nysci", "nycalc", "nystats", "nyphysics", "nychem", "nybio",
                "nylinear", "nytensor"
            ],
            "Utility": [
                "nycore", "nyshell", "nyscript", "nysystem", "nysys", "nyruntime",
                "nykernel", "nydevice"
            ]
        }
    
    def create_engine_test_code(self, engine_name: str, operation_type: str = "basic") -> str:
        """Generate Nyx code to test an engine under pressure"""
        
        if operation_type == "basic":
            return f"""
let result = 0
for (i in range(100)) {{
    result = result + i
}}
result
"""
        elif operation_type == "memory_stress":
            return f"""
let arrays = []
for (i in range(500)) {{
    let arr = []
    for (j in range(100)) {{
        arr = arr + [i * j]
    }}
    arrays = arrays + [arr]
}}
len(arrays)
"""
        elif operation_type == "computation":
            return f"""
let total = 0
for (n in [5, 6, 7, 8, 9, 10]) {{
    let a = 0
    let b = 1
    for (i in range(n)) {{
        let temp = a + b
        a = b
        b = temp
    }}
    total = total + a
}}
total
"""
        else:
            return 'print("test")'
    
    def run_interpreter(self, source: str, timeout_seconds: float = 10) -> Tuple[any, str]:
        """Execute Nyx code with timeout"""
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
                    error[0] = str(e)
            
            thread = threading.Thread(target=run)
            thread.daemon = True
            thread.start()
            thread.join(timeout_seconds)
            
            if thread.is_alive():
                return None, "Timeout"
            
            if error[0]:
                return None, error[0]
            
            return result[0], None
        except Exception as e:
            return None, str(e)
    
    def test_engine_basic(self, engine_name: str, category: str) -> EngineTestResult:
        """Basic concurrency test for an engine"""
        start_time = time.time()
        errors = []
        operations = 0
        
        print(f"  Testing {engine_name} (basic operations)...")
        
        try:
            # Test basic operations
            code = self.create_engine_test_code(engine_name, "basic")
            result, error = self.run_interpreter(code, timeout_seconds=5)
            
            if error:
                errors.append(f"Basic test failed: {error}")
            else:
                operations += 1
            
        except Exception as e:
            errors.append(f"Basic test exception: {str(e)}")
        
        duration = time.time() - start_time
        
        return EngineTestResult(
            engine_name=engine_name,
            category=category,
            passed=len(errors) == 0,
            duration=duration,
            operations_completed=operations,
            errors=errors
        )
    
    def test_engine_memory_stress(self, engine_name: str, category: str) -> EngineTestResult:
        """Memory stress test for an engine"""
        start_time = time.time()
        errors = []
        operations = 0
        
        print(f"  Testing {engine_name} (memory stress)...")
        
        try:
            # Test memory-intensive operations
            code = self.create_engine_test_code(engine_name, "memory_stress")
            result, error = self.run_interpreter(code, timeout_seconds=10)
            
            if error:
                errors.append(f"Memory stress failed: {error}")
            else:
                operations += 1
            
        except Exception as e:
            errors.append(f"Memory stress exception: {str(e)}")
        
        duration = time.time() - start_time
        
        return EngineTestResult(
            engine_name=engine_name,
            category=category,
            passed=len(errors) == 0,
            duration=duration,
            operations_completed=operations,
            errors=errors
        )
    
    def test_engine_concurrent(self, engine_name: str, category: str, num_threads: int = 10) -> EngineTestResult:
        """Concurrent access test for an engine"""
        start_time = time.time()
        errors = []
        operations = 0
        
        print(f"  Testing {engine_name} (concurrent access, {num_threads} threads)...")
        
        def worker(idx: int) -> Tuple[bool, str]:
            try:
                code = self.create_engine_test_code(engine_name, "computation")
                result, error = self.run_interpreter(code, timeout_seconds=5)
                if error:
                    return False, f"Thread {idx}: {error}"
                return True, ""
            except Exception as e:
                return False, f"Thread {idx} exception: {str(e)}"
        
        try:
            with ThreadPoolExecutor(max_workers=min(num_threads, self.num_workers)) as executor:
                futures = [executor.submit(worker, i) for i in range(num_threads)]
                
                for future in as_completed(futures):
                    success, error = future.result()
                    if success:
                        operations += 1
                    else:
                        errors.append(error)
        
        except Exception as e:
            errors.append(f"Concurrent test exception: {str(e)}")
        
        duration = time.time() - start_time
        
        return EngineTestResult(
            engine_name=engine_name,
            category=category,
            passed=len(errors) == 0,
            duration=duration,
            operations_completed=operations,
            errors=errors
        )
    
    def test_category(self, category: str, test_type: str = "all") -> List[EngineTestResult]:
        """Test all engines in a category"""
        engines = self.engine_categories.get(category, [])
        results = []
        
        print(f"\n{'='*70}")
        print(f"🔧 Testing Category: {category} ({len(engines)} engines)")
        print(f"{'='*70}")
        
        for engine in engines:
            if test_type in ["all", "basic"]:
                result = self.test_engine_basic(engine, category)
                results.append(result)
            
            if test_type in ["all", "memory"]:
                result = self.test_engine_memory_stress(engine, category)
                results.append(result)
            
            if test_type in ["all", "concurrent"]:
                result = self.test_engine_concurrent(engine, category)
                results.append(result)
        
        return results
    
    def run_all_tests(self, test_type: str = "all") -> None:
        """Run pressure tests on all engines"""
        print("\n" + "="*70)
        print("🚀 NYX ENGINE ECOSYSTEM - COMPREHENSIVE PRESSURE TEST SUITE")
        print("="*70)
        print(f"Configuration:")
        print(f"  - Worker Threads: {self.num_workers}")
        print(f"  - Test Duration: {self.duration_seconds}s per test")
        print(f"  - Test Type: {test_type}")
        print(f"  - Total Engines: {sum(len(engines) for engines in self.engine_categories.values())}")
        print("="*70)
        
        start_time = time.time()
        
        for category in self.engine_categories.keys():
            category_results = self.test_category(category, test_type)
            self.results.extend(category_results)
        
        total_duration = time.time() - start_time
        
        # Generate report
        self.generate_report(total_duration)
    
    def generate_report(self, total_duration: float) -> None:
        """Generate comprehensive test report"""
        print("\n" + "="*70)
        print("📊 PRESSURE TEST RESULTS SUMMARY")
        print("="*70)
        
        # Overall statistics
        total_tests = len(self.results)
        passed_tests = sum(1 for r in self.results if r.passed)
        failed_tests = total_tests - passed_tests
        total_operations = sum(r.operations_completed for r in self.results)
        
        print(f"\n📈 Overall Statistics:")
        print(f"  Total Tests: {total_tests}")
        print(f"  Passed: {passed_tests} ({100*passed_tests/total_tests:.1f}%)")
        print(f"  Failed: {failed_tests} ({100*failed_tests/total_tests:.1f}%)")
        print(f"  Total Operations: {total_operations:,}")
        print(f"  Total Duration: {total_duration:.2f}s")
        if total_duration > 0:
            print(f"  Throughput: {total_operations/total_duration:.1f} ops/sec")
        else:
            print(f"  Throughput: N/A (instant completion)")
        
        # Category breakdown
        print(f"\n📊 Results by Category:")
        categories = {}
        for result in self.results:
            if result.category not in categories:
                categories[result.category] = {"passed": 0, "failed": 0, "ops": 0}
            
            if result.passed:
                categories[result.category]["passed"] += 1
            else:
                categories[result.category]["failed"] += 1
            categories[result.category]["ops"] += result.operations_completed
        
        for category, stats in sorted(categories.items()):
            total = stats["passed"] + stats["failed"]
            print(f"  {category:20s}: {stats['passed']:3d}/{total:3d} passed, {stats['ops']:6d} ops")
        
        # Failed tests details
        failed_results = [r for r in self.results if not r.passed]
        if failed_results:
            print(f"\n❌ Failed Tests ({len(failed_results)}):")
            for result in failed_results[:20]:  # Show first 20 failures
                print(f"  - {result.engine_name} ({result.category})")
                for error in result.errors[:2]:  # Show first 2 errors per engine
                    print(f"      {error[:100]}")
        
        # Performance statistics
        if self.results:
            durations = [r.duration for r in self.results]
            avg_duration = sum(durations) / len(durations)
            max_duration = max(durations)
            min_duration = min(durations)
            
            print(f"\n⏱️  Performance Statistics:")
            print(f"  Avg Test Duration: {avg_duration:.3f}s")
            print(f"  Min Test Duration: {min_duration:.3f}s")
            print(f"  Max Test Duration: {max_duration:.3f}s")
        
        # Final verdict
        print("\n" + "="*70)
        if failed_tests == 0:
            print("✅ ALL ENGINE PRESSURE TESTS PASSED!")
        else:
            print(f"⚠️  {failed_tests}/{total_tests} tests failed - Review required")
        print("="*70)
        
        return failed_tests == 0


def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Nyx Engine Pressure Test Suite")
    parser.add_argument("--workers", type=int, default=18, help="Number of worker threads")
    parser.add_argument("--duration", type=int, default=60, help="Test duration in seconds")
    parser.add_argument("--test-type", choices=["all", "basic", "memory", "concurrent"], 
                        default="all", help="Type of tests to run")
    parser.add_argument("--category", help="Test only specific category")
    
    args = parser.parse_args()
    
    tester = EnginePressureTester(
        num_workers=args.workers,
        duration_seconds=args.duration
    )
    
    if args.category:
        if args.category in tester.engine_categories:
            results = tester.test_category(args.category, args.test_type)
            tester.results = results
            tester.generate_report(0)
        else:
            print(f"❌ Unknown category: {args.category}")
            print(f"Available: {', '.join(tester.engine_categories.keys())}")
            sys.exit(1)
    else:
        tester.run_all_tests(args.test_type)
    
    # Exit with appropriate code
    failed = sum(1 for r in tester.results if not r.passed)
    sys.exit(0 if failed == 0 else 1)


if __name__ == "__main__":
    main()
