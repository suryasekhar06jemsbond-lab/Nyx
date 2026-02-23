#!/usr/bin/env python3
"""
===================================================================================
MASTER ENGINE PRESSURE TEST RUNNER
Runs all engine pressure tests and aggregates results
===================================================================================
"""

import sys
import os
import subprocess
import time
from datetime import datetime
from typing import List, Dict

# Fix Windows encoding issues with Unicode
if sys.platform == "win32":
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

class MasterTestRunner:
    """Orchestrates all engine pressure tests"""
    
    def __init__(self):
        self.test_dir = os.path.dirname(os.path.abspath(__file__))
        self.test_files = [
            "test_all_engines_pressure.py",
            "test_aiml_engines_pressure.py",
            "test_data_engines_pressure.py",
        ]
        self.results: List[Dict] = []
    
    def run_test_file(self, test_file: str) -> Dict:
        """Run a single test file and capture results"""
        print(f"\n{'='*80}")
        print(f"🚀 Running: {test_file}")
        print(f"{'='*80}\n")
        
        file_path = os.path.join(self.test_dir, test_file)
        start_time = time.time()
        
        try:
            result = subprocess.run(
                [sys.executable, file_path],
                capture_output=True,
                text=True,
                encoding='utf-8',
                errors='replace',
                timeout=600  # 10 minute timeout per test file
            )
            
            duration = time.time() - start_time
            
            return {
                "file": test_file,
                "success": result.returncode == 0,
                "duration": duration,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "returncode": result.returncode
            }
        
        except subprocess.TimeoutExpired:
            duration = time.time() - start_time
            return {
                "file": test_file,
                "success": False,
                "duration": duration,
                "stdout": "",
                "stderr": "Test timed out after 10 minutes",
                "returncode": -1
            }
        
        except Exception as e:
            duration = time.time() - start_time
            return {
                "file": test_file,
                "success": False,
                "duration": duration,
                "stdout": "",
                "stderr": str(e),
                "returncode": -2
            }
    
    def run_all_tests(self):
        """Run all engine pressure tests"""
        print("\n" + "="*80)
        print("🏁 MASTER ENGINE PRESSURE TEST RUNNER")
        print("="*80)
        print(f"Start Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"Test Files: {len(self.test_files)}")
        print("="*80)
        
        overall_start = time.time()
        
        for test_file in self.test_files:
            # Check if file exists
            file_path = os.path.join(self.test_dir, test_file)
            if not os.path.exists(file_path):
                print(f"⚠️  Skipping {test_file} (file not found)")
                continue
            
            result = self.run_test_file(test_file)
            self.results.append(result)
            
            # Print output
            if result["stdout"]:
                print(result["stdout"])
            if result["stderr"]:
                print(f"STDERR:\n{result['stderr']}")
            
            # Print summary for this test
            status = "✅ PASSED" if result["success"] else "❌ FAILED"
            print(f"\n{status} - {test_file} ({result['duration']:.2f}s)")
        
        overall_duration = time.time() - overall_start
        
        # Generate master report
        self.generate_master_report(overall_duration)
    
    def generate_master_report(self, total_duration: float):
        """Generate comprehensive master report"""
        print("\n" + "="*80)
        print("📊 MASTER PRESSURE TEST REPORT")
        print("="*80)
        print(f"End Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"Total Duration: {total_duration:.2f}s ({total_duration/60:.1f} minutes)")
        print("="*80)
        
        total_tests = len(self.results)
        passed_tests = sum(1 for r in self.results if r["success"])
        failed_tests = total_tests - passed_tests
        
        print(f"\n📈 Summary:")
        print(f"  Total Test Suites: {total_tests}")
        print(f"  Passed: {passed_tests}")
        print(f"  Failed: {failed_tests}")
        print(f"  Success Rate: {100*passed_tests/total_tests:.1f}%")
        
        print(f"\n📋 Test Suite Results:")
        for result in self.results:
            status = "✅" if result["success"] else "❌"
            print(f"  {status} {result['file']:40s} | {result['duration']:7.2f}s | "
                  f"Exit Code: {result['returncode']}")
        
        if failed_tests > 0:
            print(f"\n❌ Failed Test Suites:")
            for result in self.results:
                if not result["success"]:
                    print(f"  - {result['file']}")
                    if result["stderr"]:
                        print(f"    Error: {result['stderr'][:200]}")
        
        print("\n" + "="*80)
        if failed_tests == 0:
            print("✅ ALL ENGINE PRESSURE TEST SUITES PASSED!")
            print("🎉 All 123 engines validated under pressure conditions")
        else:
            print(f"⚠️  {failed_tests}/{total_tests} test suites failed")
            print("📝 Review errors above for details")
        print("="*80)
        
        # Write results to file
        self.write_results_file()
        
        return failed_tests == 0
    
    def write_results_file(self):
        """Write detailed results to file"""
        results_file = os.path.join(self.test_dir, "engine_pressure_test_results.txt")
        
        try:
            with open(results_file, 'w', encoding='utf-8') as f:
                f.write("="*80 + "\n")
                f.write("ENGINE PRESSURE TEST RESULTS\n")
                f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
                f.write("="*80 + "\n\n")
                
                for result in self.results:
                    f.write(f"\n{'='*80}\n")
                    f.write(f"Test: {result['file']}\n")
                    f.write(f"Status: {'PASSED' if result['success'] else 'FAILED'}\n")
                    f.write(f"Duration: {result['duration']:.2f}s\n")
                    f.write(f"Exit Code: {result['returncode']}\n")
                    f.write(f"{'='*80}\n\n")
                    
                    if result['stdout']:
                        f.write("STDOUT:\n")
                        f.write(result['stdout'])
                        f.write("\n\n")
                    
                    if result['stderr']:
                        f.write("STDERR:\n")
                        f.write(result['stderr'])
                        f.write("\n\n")
            
            print(f"\n📄 Detailed results written to: {results_file}")
        
        except Exception as e:
            print(f"\n⚠️  Could not write results file: {e}")


def main():
    runner = MasterTestRunner()
    runner.run_all_tests()
    
    # Exit with appropriate code
    failed = sum(1 for r in runner.results if not r["success"])
    sys.exit(0 if failed == 0 else 1)


if __name__ == "__main__":
    main()
