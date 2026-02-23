#!/usr/bin/env python3
"""
🔥 MIXED SUBSYSTEM STRESS TEST - 5 MINUTE CONCURRENT WORKLOAD
==============================================================

Tests all Nyx engines under mixed production-like scenario with:
- AI training loop (gradient computation, optimization)
- Web server (request handling, concurrency)
- Data pipeline (transformation, batching, caching)
- Storage engine (writes, reads, persistence)
- Logging engine (event logging, buffering, flushing)

All running simultaneously for realism.
"""

import sys
import os
import time
import threading
import random
import string
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import json

# UTF-8 encoding for Windows
if sys.platform == "win32":
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from src.lexer import Lexer
from src.parser import Parser
from src.interpreter import Interpreter, Environment

# Configuration
TEST_DURATION = 5 * 60  # 5 minutes
SNAPSHOT_INTERVAL = 10  # 10 seconds
MAX_WORKERS = os.cpu_count() or 8

class SubsystemMonitor:
    """Monitor subsystem performance"""
    
    def __init__(self):
        self.results = {
            'ai_training': {'total': 0, 'passed': 0, 'failed': 0, 'duration': 0},
            'web_server': {'total': 0, 'passed': 0, 'failed': 0, 'duration': 0},
            'data_pipeline': {'total': 0, 'passed': 0, 'failed': 0, 'duration': 0},
            'storage_engine': {'total': 0, 'passed': 0, 'failed': 0, 'duration': 0},
            'logging_engine': {'total': 0, 'passed': 0, 'failed': 0, 'duration': 0}
        }
        self.snapshots = []
        self.lock = threading.Lock()
    
    def record_result(self, subsystem, passed, duration):
        """Record a test result"""
        with self.lock:
            self.results[subsystem]['total'] += 1
            if passed:
                self.results[subsystem]['passed'] += 1
            else:
                self.results[subsystem]['failed'] += 1
            self.results[subsystem]['duration'] += duration
    
    def take_snapshot(self, elapsed):
        """Take a performance snapshot"""
        try:
            import psutil
            process = psutil.Process()
            mem = process.memory_info()
            sys_mem = psutil.virtual_memory()
            
            snapshot = {
                'elapsed': elapsed,
                'memory_mb': mem.rss / 1024 / 1024,
                'system_percent': sys_mem.percent,
                'cpu_percent': psutil.cpu_percent(interval=0.5),
                'threads': process.num_threads(),
                'subsystem_stats': dict(self.results)
            }
        except ImportError:
            snapshot = {
                'elapsed': elapsed,
                'memory_mb': 0,
                'system_percent': 0,
                'cpu_percent': 0,
                'threads': threading.active_count(),
                'subsystem_stats': dict(self.results)
            }
        
        with self.lock:
            self.snapshots.append(snapshot)
        return snapshot


class AITrainingWorkload:
    """AI/ML training simulation"""
    
    @staticmethod
    def run_training_iteration():
        """Simulate AI training with gradient computation"""
        code = """
let learning_rate = 0.01
let weights = []
for (i in range(100)) {
    weights = weights + [0.5 + i * 0.001]
}

let gradients = []
for (i in range(100)) {
    let g = 0
    for (j in range(10)) {
        g = g + weights[i] * j
    }
    gradients = gradients + [g]
}

let updated = []
for (i in range(100)) {
    updated = updated + [weights[i] - learning_rate * gradients[i]]
}

len(updated)
"""
        try:
            lexer = Lexer(code)
            parser = Parser(lexer)
            program = parser.parse()
            interpreter = Interpreter()
            env = Environment()
            result = interpreter.eval(program, env)
            return True
        except Exception:
            return False
    
    def run(self, monitor, duration):
        """Run training loop"""
        start = time.time()
        count = 0
        while time.time() - start < duration:
            t0 = time.time()
            success = self.run_training_iteration()
            elapsed = time.time() - t0
            monitor.record_result('ai_training', success, elapsed)
            count += 1
        return count


class WebServerWorkload:
    """Web server request handling simulation"""
    
    @staticmethod
    def simulate_request():
        """Simulate handling a web request"""
        code = """
let request = [
    "GET",
    "/api/data",
    ["Content-Type", "application/json"]
]

let response = []
for (i in range(20)) {
    let data = "user_" + i
    response = response + [data]
}

let json_size = 0
for (r in response) {
    json_size = json_size + 1
}

json_size
"""
        try:
            lexer = Lexer(code)
            parser = Parser(lexer)
            program = parser.parse()
            interpreter = Interpreter()
            env = Environment()
            result = interpreter.eval(program, env)
            return True
        except Exception:
            return False
    
    def run(self, monitor, duration):
        """Run web server simulation"""
        start = time.time()
        count = 0
        while time.time() - start < duration:
            t0 = time.time()
            success = self.simulate_request()
            elapsed = time.time() - t0
            monitor.record_result('web_server', success, elapsed)
            count += 1
        return count


class DataPipelineWorkload:
    """Data pipeline processing simulation"""
    
    @staticmethod
    def process_batch():
        """Simulate data pipeline: transform -> batch -> cache"""
        code = """
let raw_data = []
for (i in range(50)) {
    raw_data = raw_data + [i * 2]
}

let transformed = []
for (val in raw_data) {
    transformed = transformed + [val + 100]
}

let batches = []
let batch = []
for (item in transformed) {
    batch = batch + [item]
    if (len(batch) == 10) {
        batches = batches + [batch]
        batch = []
    }
}

let cache_hits = 0
for (b in batches) {
    cache_hits = cache_hits + len(b)
}

cache_hits
"""
        try:
            lexer = Lexer(code)
            parser = Parser(lexer)
            program = parser.parse()
            interpreter = Interpreter()
            env = Environment()
            result = interpreter.eval(program, env)
            return True
        except Exception:
            return False
    
    def run(self, monitor, duration):
        """Run data pipeline"""
        start = time.time()
        count = 0
        while time.time() - start < duration:
            t0 = time.time()
            success = self.process_batch()
            elapsed = time.time() - t0
            monitor.record_result('data_pipeline', success, elapsed)
            count += 1
        return count


class StorageEngineWorkload:
    """Storage engine write/read simulation"""
    
    @staticmethod
    def write_read_cycle():
        """Simulate storage engine writes and reads"""
        code = """
let store = []
for (i in range(100)) {
    let record = []
    for (j in range(5)) {
        record = record + [i * j]
    }
    store = store + [record]
}

let read_count = 0
for (record in store) {
    read_count = read_count + len(record)
}

let indexed = []
for (i in range(50)) {
    if (i < len(store)) {
        indexed = indexed + [store[i]]
    }
}

read_count
"""
        try:
            lexer = Lexer(code)
            parser = Parser(lexer)
            program = parser.parse()
            interpreter = Interpreter()
            env = Environment()
            result = interpreter.eval(program, env)
            return True
        except Exception:
            return False
    
    def run(self, monitor, duration):
        """Run storage engine simulation"""
        start = time.time()
        count = 0
        while time.time() - start < duration:
            t0 = time.time()
            success = self.write_read_cycle()
            elapsed = time.time() - t0
            monitor.record_result('storage_engine', success, elapsed)
            count += 1
        return count


class LoggingEngineWorkload:
    """Logging engine activity simulation"""
    
    @staticmethod
    def log_events():
        """Simulate logging with buffering and flushing"""
        code = """
let log_buffer = []
let timestamps = []

for (i in range(50)) {
    let event = "event_" + i
    log_buffer = log_buffer + [event]
    timestamps = timestamps + [i]
}

let flushed = 0
for (log in log_buffer) {
    flushed = flushed + 1
}

let stats = []
for (t in timestamps) {
    stats = stats + [t * 2]
}

flushed
"""
        try:
            lexer = Lexer(code)
            parser = Parser(lexer)
            program = parser.parse()
            interpreter = Interpreter()
            env = Environment()
            result = interpreter.eval(program, env)
            return True
        except Exception:
            return False
    
    def run(self, monitor, duration):
        """Run logging engine simulation"""
        start = time.time()
        count = 0
        while time.time() - start < duration:
            t0 = time.time()
            success = self.log_events()
            elapsed = time.time() - t0
            monitor.record_result('logging_engine', success, elapsed)
            count += 1
        return count


def run_mixed_subsystem_stress():
    """Run mixed subsystem stress test"""
    
    print("="*80)
    print("🔥 MIXED SUBSYSTEM STRESS TEST - 5 MINUTE CONCURRENT WORKLOAD")
    print("="*80)
    print(f"CPU Cores: {MAX_WORKERS}")
    print(f"Duration: 5 minutes")
    print(f"Workloads: AI Training + Web Server + Data Pipeline + Storage + Logging")
    print(f"Snapshots: Every 10 seconds")
    print("="*80)
    print()
    
    monitor = SubsystemMonitor()
    start_time = time.time()
    end_time = start_time + TEST_DURATION
    next_snapshot = start_time + SNAPSHOT_INTERVAL
    
    # Initialize workloads
    ai = AITrainingWorkload()
    web = WebServerWorkload()
    data = DataPipelineWorkload()
    storage = StorageEngineWorkload()
    logging = LoggingEngineWorkload()
    
    print("🚀 Starting mixed subsystem workloads...")
    print()
    
    # Run all workloads concurrently
    with ThreadPoolExecutor(max_workers=5) as executor:
        futures = {
            executor.submit(ai.run, monitor, TEST_DURATION): 'AI Training',
            executor.submit(web.run, monitor, TEST_DURATION): 'Web Server',
            executor.submit(data.run, monitor, TEST_DURATION): 'Data Pipeline',
            executor.submit(storage.run, monitor, TEST_DURATION): 'Storage Engine',
            executor.submit(logging.run, monitor, TEST_DURATION): 'Logging Engine'
        }
        
        # Monitor and snapshot while workloads run
        while any(not f.done() for f in futures):
            elapsed = time.time() - start_time
            
            # Take snapshot at intervals
            if time.time() >= next_snapshot:
                snapshot = monitor.take_snapshot(elapsed)
                
                # Get pass rates
                stats = {
                    'ai': f"{monitor.results['ai_training']['passed']}/{monitor.results['ai_training']['total']}",
                    'web': f"{monitor.results['web_server']['passed']}/{monitor.results['web_server']['total']}",
                    'data': f"{monitor.results['data_pipeline']['passed']}/{monitor.results['data_pipeline']['total']}",
                    'storage': f"{monitor.results['storage_engine']['passed']}/{monitor.results['storage_engine']['total']}",
                    'logging': f"{monitor.results['logging_engine']['passed']}/{monitor.results['logging_engine']['total']}"
                }
                
                print(f"📊 Snapshot @ {elapsed/60:.1f} min:")
                print(f"   AI Training: {stats['ai']} passed")
                print(f"   Web Server:  {stats['web']} passed")
                print(f"   Data Pipeline: {stats['data']} passed")
                print(f"   Storage Engine: {stats['storage']} passed")
                print(f"   Logging Engine: {stats['logging']} passed")
                
                if snapshot['memory_mb'] > 0:
                    print(f"   Memory: {snapshot['memory_mb']:.1f} MB ({snapshot['system_percent']:.1f}% system)")
                    print(f"   CPU: {snapshot['cpu_percent']:.1f}%, Threads: {snapshot['threads']}")
                print()
                
                next_snapshot += SNAPSHOT_INTERVAL
            
            time.sleep(0.5)
        
        # Collect results from all workloads
        for future, name in futures.items():
            try:
                count = future.result()
            except Exception as e:
                pass
    
    # Final results
    total_duration = time.time() - start_time
    
    print("="*80)
    print("📊 MIXED SUBSYSTEM STRESS TEST RESULTS")
    print("="*80)
    print(f"Total Duration: {total_duration:.1f} seconds ({total_duration/60:.2f} minutes)")
    print()
    
    print("📈 Subsystem Results:")
    total_tests = 0
    total_passed = 0
    
    for subsystem, stats in monitor.results.items():
        name = subsystem.replace('_', ' ').title()
        pass_rate = (stats['passed'] / stats['total'] * 100) if stats['total'] > 0 else 0
        avg_duration = stats['duration'] / stats['total'] if stats['total'] > 0 else 0
        
        status = "✅" if pass_rate == 100 else "⚠️ " if pass_rate >= 95 else "❌"
        print(f"  {status} {name:20s} | Tests: {stats['total']:4d} | Passed: {stats['passed']:4d} ({pass_rate:5.1f}%) | Avg: {avg_duration*1000:6.2f}ms")
        
        total_tests += stats['total']
        total_passed += stats['passed']
    
    print()
    overall_rate = (total_passed / total_tests * 100) if total_tests > 0 else 0
    print(f"🎯 Overall Results:")
    print(f"   Total Tests: {total_tests}")
    print(f"   Passed: {total_passed} ({overall_rate:.1f}%)")
    print(f"   Failed: {total_tests - total_passed} ({100-overall_rate:.1f}%)")
    print()
    
    # Concurrency metrics
    if monitor.snapshots:
        first_mem = monitor.snapshots[0]['memory_mb']
        last_mem = monitor.snapshots[-1]['memory_mb']
        max_mem = max(s['memory_mb'] for s in monitor.snapshots)
        avg_cpu = sum(s['cpu_percent'] for s in monitor.snapshots) / len(monitor.snapshots)
        max_threads = max(s['threads'] for s in monitor.snapshots)
        
        print(f"📊 System Metrics:")
        print(f"   Memory: {first_mem:.1f} MB → {last_mem:.1f} MB (peak: {max_mem:.1f} MB)")
        print(f"   CPU: {avg_cpu:.1f}% average")
        print(f"   Threads: Up to {max_threads}")
    
    print()
    
    # Verdict
    if overall_rate == 100:
        print("✅ MIXED SUBSYSTEM STRESS TEST PASSED")
        print("   All workloads stable when run concurrently")
    elif overall_rate >= 95:
        print("⚠️  MIXED SUBSYSTEM STRESS TEST - MINOR ISSUES")
        print(f"   {100-overall_rate:.1f}% failure rate is acceptable")
    else:
        print("❌ MIXED SUBSYSTEM STRESS TEST - FAILURES DETECTED")
        print(f"   {100-overall_rate:.1f}% failure rate - investigate")
    
    print("="*80)
    
    # Save results
    results_data = {
        'test_info': {
            'start_time': datetime.fromtimestamp(start_time).isoformat(),
            'duration_seconds': total_duration,
            'cpu_cores': MAX_WORKERS
        },
        'subsystem_results': monitor.results,
        'overall': {
            'total_tests': total_tests,
            'passed': total_passed,
            'failed': total_tests - total_passed,
            'pass_rate': overall_rate
        },
        'snapshots': monitor.snapshots
    }
    
    log_file = Path('tests/engines/mixed_subsystem_stress_log.json')
    with open(log_file, 'w', encoding='utf-8') as f:
        json.dump(results_data, f, indent=2)
    
    print(f"\n📄 Detailed log saved to: {log_file}")


if __name__ == '__main__':
    try:
        run_mixed_subsystem_stress()
    except KeyboardInterrupt:
        print("\n\n⚠️  Test interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n\n❌ Test failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
