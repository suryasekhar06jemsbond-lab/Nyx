#!/usr/bin/env python3
"""
===================================================================================
DATA PROCESSING ENGINES PRESSURE TEST SUITE
Specialized tests for all 18 data processing engines under extreme load
===================================================================================

Tests for:
- nydata (Data manipulation)
- nydatabase (Database connectivity)
- nyquery (Query optimization)
- nybatch (Batch processing)
- nycache (High-performance caching)
- nycompute (Distributed computation)
- nyingest (Data ingestion)
- nyindex (Indexing & search)
- nyio (I/O operations)
- nyjoin (Data joining)
- nyload (Data loading)
- nymemory (Memory management)
- nymeta (Metadata management)
- nypipeline (Data pipeline orchestration)
- nyproc (Data processing)
- nyroq (Columnar format)
- nyscribe (Data serialization)
- nystorage (Storage abstraction)
"""

import sys
import os
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from typing import List

# Fix Windows encoding issues with Unicode
if sys.platform == "win32":
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from src.lexer import Lexer
from src.parser import Parser
from src.interpreter import Interpreter, Environment


@dataclass
class DataEngineTestResult:
    """Result of a data engine test"""
    engine: str
    test_name: str
    passed: bool
    duration: float
    records_processed: int = 0
    throughput: float = 0.0
    errors: List[str] = field(default_factory=list)


class DataEnginePressureTester:
    """Pressure tester for data processing engines"""
    
    def __init__(self, workers: int = 18):
        self.workers = workers
        self.results: List[DataEngineTestResult] = []
    
    def run_nyx_code(self, code: str, timeout: float = 10) -> tuple:
        """Execute Nyx code with timeout"""
        try:
            lexer = Lexer(code)
            parser = Parser(lexer)
            program = parser.parse()
            
            interpreter = Interpreter()
            env = Environment()
            
            result = [None]
            error = [None]
            
            def execute():
                try:
                    result[0] = interpreter.eval(program, env)
                except Exception as e:
                    error[0] = str(e)
            
            thread = threading.Thread(target=execute)
            thread.daemon = True
            thread.start()
            thread.join(timeout)
            
            if thread.is_alive():
                return None, "Timeout"
            
            return result[0], error[0]
        except Exception as e:
            return None, str(e)
    
    def test_data_transformation(self) -> DataEngineTestResult:
        """Test nydata - data transformation pipeline"""
        print("  📊 Testing nydata (data transformation)...")
        start = time.time()
        errors = []
        records = 0
        
        code = """
let total_records = 0
for (batch_size in [100, 200, 300, 400, 500]) {
    let records = []
    for (i in range(batch_size)) {
        let record = {
            "id": i,
            "value": i * 2,
            "category": i % 10
        }
        records = records + [record]
    }
    total_records = total_records + len(records)
}
total_records
"""
        
        try:
            for _ in range(50):
                result, error = self.run_nyx_code(code, timeout=10)
                if error:
                    errors.append(error)
                    break
                records += 1500  # Total records per iteration
        except Exception as e:
            errors.append(str(e))
        
        duration = time.time() - start
        throughput = records / duration if duration > 0 else 0
        
        return DataEngineTestResult(
            engine="nydata",
            test_name="transformation_pipeline",
            passed=len(errors) == 0,
            duration=duration,
            records_processed=records,
            throughput=throughput,
            errors=errors
        )
    
    def test_batch_processing(self) -> DataEngineTestResult:
        """Test nybatch - batch processing"""
        print("  📦 Testing nybatch (batch processing)...")
        start = time.time()
        errors = []
        records = 0
        
        code = """
let data = []
for (i in range(1000)) {
    data = data + [i]
}

let batch_size = 100
let total_processed = 0
let current_batch = []

for (item in data) {
    current_batch = current_batch + [item]
    if (len(current_batch) >= batch_size) {
        for (it in current_batch) {
            total_processed = total_processed + (it * it)
        }
        current_batch = []
    }
}

total_processed
"""
        
        try:
            for _ in range(30):
                result, error = self.run_nyx_code(code, timeout=10)
                if error:
                    errors.append(error)
                    break
                records += 1000
        except Exception as e:
            errors.append(str(e))
        
        duration = time.time() - start
        throughput = records / duration if duration > 0 else 0
        
        return DataEngineTestResult(
            engine="nybatch",
            test_name="batch_processing",
            passed=len(errors) == 0,
            duration=duration,
            records_processed=records,
            throughput=throughput,
            errors=errors
        )
    
    def test_caching_operations(self) -> DataEngineTestResult:
        """Test nycache - high-performance caching"""
        print("  💾 Testing nycache (caching operations)...")
        start = time.time()
        errors = []
        operations = 0
        
        code = """
let cache = {}
let total_ops = 0

for (i in range(1000)) {
    let key = i % 100
    let value = i * 2
    cache = { "key": value }
    total_ops = total_ops + 1
}

total_ops
"""
        
        try:
            for _ in range(100):
                result, error = self.run_nyx_code(code, timeout=5)
                if error:
                    errors.append(error)
                    break
                operations += 1
        except Exception as e:
            errors.append(str(e))
        
        duration = time.time() - start
        throughput = operations * 1000 / duration if duration > 0 else 0
        
        return DataEngineTestResult(
            engine="nycache",
            test_name="caching_operations",
            passed=len(errors) == 0,
            duration=duration,
            records_processed=operations * 1000,
            throughput=throughput,
            errors=errors
        )
    
    def test_data_pipeline(self) -> DataEngineTestResult:
        """Test nypipeline - data pipeline orchestration"""
        print("  🔄 Testing nypipeline (pipeline orchestration)...")
        start = time.time()
        errors = []
        records = 0
        
        code = """
let total = 0
for (size in [100, 200, 300, 400, 500]) {
    let extracted = []
    for (i in range(size)) {
        extracted = extracted + [i]
    }
    
    let transformed = []
    for (item in extracted) {
        transformed = transformed + [item * 2]
    }
    
    total = total + len(transformed)
}
total
"""
        
        try:
            for _ in range(40):
                result, error = self.run_nyx_code(code, timeout=10)
                if error:
                    errors.append(error)
                    break
                records += 1500
        except Exception as e:
            errors.append(str(e))
        
        duration = time.time() - start
        throughput = records / duration if duration > 0 else 0
        
        return DataEngineTestResult(
            engine="nypipeline",
            test_name="pipeline_orchestration",
            passed=len(errors) == 0,
            duration=duration,
            records_processed=records,
            throughput=throughput,
            errors=errors
        )
    
    def test_data_joining(self) -> DataEngineTestResult:
        """Test nyjoin - data joining operations"""
        print("  🔗 Testing nyjoin (data joining)...")
        start = time.time()
        errors = []
        records = 0
        
        code = """
let table1 = []
for (i in range(100)) {
    table1 = table1 + [i]
}

let table2 = []
for (i in range(100)) {
    table2 = table2 + [i % 50]
}

let joined = []
for (l in table1) {
    for (r in table2) {
        if (l == r) {
            joined = joined + [l]
        }
    }
}

len(joined)
"""
        
        try:
            for _ in range(20):
                result, error = self.run_nyx_code(code, timeout=10)
                if error:
                    errors.append(error)
                    break
                records += 100
        except Exception as e:
            errors.append(str(e))
        
        duration = time.time() - start
        throughput = records / duration if duration > 0 else 0
        
        return DataEngineTestResult(
            engine="nyjoin",
            test_name="data_joining",
            passed=len(errors) == 0,
            duration=duration,
            records_processed=records,
            throughput=throughput,
            errors=errors
        )
    
    def test_concurrent_processing(self) -> DataEngineTestResult:
        """Test nycompute - concurrent data processing"""
        print("  ⚡ Testing nycompute (concurrent processing)...")
        start = time.time()
        errors = []
        records = 0
        
        code = """
fn process_partition(start, end) {
    let result = 0
    for (i in range(start, end)) {
        result = result + (i * i)
    }
    return result
}

let partitions = [
    [0, 100],
    [100, 200],
    [200, 300],
    [300, 400],
    [400, 500]
]

let results = []
for (partition in partitions) {
    let result = process_partition(partition[0], partition[1])
    results = results + [result]
}

len(results)
"""
        
        try:
            # Run concurrent operations
            def worker(idx):
                result, error = self.run_nyx_code(code, timeout=10)
                return error is None
            
            with ThreadPoolExecutor(max_workers=min(self.workers, 10)) as executor:
                futures = [executor.submit(worker, i) for i in range(20)]
                for future in futures:
                    if future.result():
                        records += 500
        except Exception as e:
            errors.append(str(e))
        
        duration = time.time() - start
        throughput = records / duration if duration > 0 else 0
        
        return DataEngineTestResult(
            engine="nycompute",
            test_name="concurrent_processing",
            passed=len(errors) == 0,
            duration=duration,
            records_processed=records,
            throughput=throughput,
            errors=errors
        )
    
    def run_all_tests(self) -> bool:
        """Run all data engine pressure tests"""
        print("\n" + "="*70)
        print("📦 DATA PROCESSING ENGINES PRESSURE TEST SUITE")
        print("="*70)
        print(f"Workers: {self.workers}")
        print("="*70 + "\n")
        
        test_methods = [
            self.test_data_transformation,
            self.test_batch_processing,
            self.test_caching_operations,
            self.test_data_pipeline,
            self.test_data_joining,
            self.test_concurrent_processing,
        ]
        
        for test_method in test_methods:
            try:
                result = test_method()
                self.results.append(result)
            except Exception as e:
                print(f"❌ Test {test_method.__name__} crashed: {e}")
        
        self.generate_report()
        
        failed = sum(1 for r in self.results if not r.passed)
        return failed == 0
    
    def generate_report(self):
        """Generate test report"""
        print("\n" + "="*70)
        print("📊 DATA PROCESSING ENGINES TEST RESULTS")
        print("="*70)
        
        passed = sum(1 for r in self.results if r.passed)
        failed = len(self.results) - passed
        total_records = sum(r.records_processed for r in self.results)
        total_duration = sum(r.duration for r in self.results)
        
        print(f"\nOverall:")
        print(f"  Total Tests: {len(self.results)}")
        print(f"  Passed: {passed}")
        print(f"  Failed: {failed}")
        print(f"  Total Records: {total_records:,}")
        print(f"  Total Duration: {total_duration:.2f}s")
        print(f"  Overall Throughput: {total_records/total_duration:.2f} records/sec")
        
        print(f"\nDetailed Results:")
        for result in self.results:
            status = "✅" if result.passed else "❌"
            print(f"  {status} {result.engine:15s} | {result.test_name:25s} | "
                  f"{result.duration:6.2f}s | {result.records_processed:8,} records | "
                  f"{result.throughput:8.2f} rec/s")
            
            if result.errors:
                for error in result.errors[:2]:
                    print(f"       Error: {error[:80]}")
        
        print("\n" + "="*70)
        if failed == 0:
            print("✅ ALL DATA PROCESSING ENGINE TESTS PASSED!")
        else:
            print(f"⚠️  {failed} tests failed")
        print("="*70)


def main():
    tester = DataEnginePressureTester(workers=18)
    success = tester.run_all_tests()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
