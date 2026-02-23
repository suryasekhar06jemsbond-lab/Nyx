# 🔥 Thermal Soak Test - 2 Hour Stress Test

**Comprehensive stress testing suite for detecting memory leaks, performance issues, and system instability.**

## Overview

This test runs for **2 hours** with amplified workload to compress leak detection time from 24+ hours into 2 hours.

### What It Does

1. **🔥 Thermal Soak (2 hours)**
   - Runs with 2×CPU workers (24-36 workers on i7 12th gen)
   - Memory snapshots every 5 minutes
   - Thread count logging
   - CPU utilization & temperature monitoring

2. **⚡ Leak Amplification**
   - Iterations ×10
   - Data size ×5
   - Concurrency ×2
   - **Result:** Leaks that take 24 hours appear in ~2 hours

3. **🔄 Burst + Idle Pattern**
   - 10 minutes max stress (BURST)
   - 5 minutes idle (IDLE)
   - Repeat cycle
   - **Why:** Idle periods expose deferred frees, thread cleanup failures, and pool shrink failures

4. **🧪 Determinism Test**
   - Runs same test twice
   - Compares output hashes
   - **Instant validation** of deterministic behavior

5. **💥 Crash Injection**
   - Randomly interrupts operations (5% probability)
   - Tests resilience to failures
   - Validates no deadlocks or memory corruption

## Safety Features

### Hardware Protection ✅

| Protection | Limit | Action |
|------------|-------|--------|
| **CPU Temperature** | 85°C max | Immediate idle if exceeded |
| **Memory Usage** | 80% system max | Pause test, force idle |
| **Timeout** | 10s per test | Kills hung processes |
| **Workers** | 2×CPU cores | Safe concurrency limit |

**Safe for i7 12th gen (12-16 cores)** - Will use ~24-32 workers max.

### What Happens on Overheat?

```
⚠️  WARNING: CPU temperature at 86.2°C - Forcing IDLE
⚠️  Safety limits exceeded - Forcing extended idle period...
```

The test automatically:
1. Stops all work immediately
2. Enters extended idle (10 minutes)
3. Monitors temperature recovery
4. Only resumes when safe

## Usage

### Basic Run (2 hours)

```bash
python tests/engines/test_thermal_soak.py
```

### What You'll See

```
🔥 THERMAL SOAK TEST - 2 HOUR ENGINE STRESS
================================================================================
CPU Cores: 12
Max Workers: 24 (2x CPU)
Duration: 2 hours
Pattern: 10min BURST → 5min IDLE → repeat
Amplification: 10x iterations, 5x data, 2x concurrency
================================================================================

🧪 Phase 0: Determinism Validation
✅ DETERMINISTIC: Both runs produced identical output
   Hash: a3f5c8d9...

📊 Initial State:
   Memory: 145.3 MB (12.4% system)
   Threads: 24
   CPU: 3.2%
   Temp: 42.5°C

🔥 Starting Thermal Soak...
Start time: 14:23:15
End time: 16:23:15

================================================================================
🔄 CYCLE 1 | Elapsed: 0.1 min / 120 min
================================================================================

🔥 BURST Phase (10 minutes) - 15 engines @ 48 workers
✅ Burst completed: 12 iterations in 605.3s
   Passed: 540, Failed: 0

💤 IDLE Phase (5 minutes) - Monitoring memory recovery...
📊 Idle Recovery Check @ 17.5 min:
   Memory: 324.5 MB → 168.2 MB
   Recovery: 48.2% (GOOD - memory dropping)
   Threads: 24
   Temp: 58.3°C (cooling)

🔍 Leak Analysis:
   Growth Rate: 2.34 MB/hour
   Total Growth: 0.45 MB over 0.19 hours
   Idle Recovery: 48.2%
   ✅ No significant leak detected

📊 Snapshot @ 20.0 min:
   Memory: 156.8 MB (13.1% system)
   Threads: 24
   CPU: 45.3%
   Temp: 64.2°C
```

### Output Files

After completion, you'll get:

1. **Console output** with real-time progress
2. **`thermal_soak_log.json`** - Detailed log with all snapshots

```json
{
  "test_info": {
    "start_time": "2026-02-23T14:23:15",
    "duration_seconds": 7200,
    "cpu_count": 12,
    "max_workers": 24
  },
  "results": {
    "passed": 6480,
    "failed": 0,
    "total": 6480,
    "cycles": 8
  },
  "leak_analysis": {
    "growth_rate_mb_per_hour": 2.34,
    "leak_detected": false
  },
  "snapshots": [...]
}
```

## Interpreting Results

### ✅ PASS Criteria

```
✅ THERMAL SOAK TEST PASSED
   No leaks detected, all systems stable
```

**Indicators:**
- Memory growth < 10 MB/hour
- Memory recovers during idle (>30% drop)
- CPU temperature stays < 85°C
- Test completion rate > 95%
- Deterministic behavior confirmed

### ⚠️ WARNING Criteria

```
⚠️  TEST COMPLETED WITH WARNINGS
   Memory leak detected - review trend data
```

**Indicators:**
- Memory growth > 10 MB/hour
- Memory does NOT recover during idle
- High failure rate (>5%)
- Non-deterministic outputs

### 🔍 Leak Detection

The test uses **slope-based detection** (not time-based):

| Growth Rate | Verdict | Projected Daily |
|-------------|---------|-----------------|
| < 5 MB/hour | ✅ No leak | < 120 MB/day |
| 5-10 MB/hour | ⚠️ Monitor | 120-240 MB/day |
| > 10 MB/hour | ❌ Leak detected | > 240 MB/day |

**Idle Recovery Test:**
- If memory drops 30%+ during idle → ✅ Healthy
- If memory stays flat during idle → ⚠️ Retention issue
- If memory grows during idle → ❌ Leak confirmed

## Example Results

### Good Run ✅

```
📊 THERMAL SOAK TEST RESULTS
================================================================================
Duration: 120.3 minutes (2.01 hours)
Cycles Completed: 8
Total Tests: 6480
Passed: 6480 (100.0%)
Failed: 0 (0.0%)
Crashes Injected: 324
Crashes Survived: 324
Deterministic: ✅ YES

📊 Final State:
   Memory: 167.2 MB (13.8% system)
   Threads: 24
   CPU: 2.1%
   Temp: 45.3°C

🔍 Final Leak Analysis:
   Growth Rate: 3.42 MB/hour
   Total Growth: 6.89 MB
   Idle Recovery: 42.3%
   ✅ NO MEMORY LEAK DETECTED
```

### Leak Detected ⚠️

```
🔍 Final Leak Analysis:
   Growth Rate: 15.67 MB/hour
   Total Growth: 31.54 MB
   Idle Recovery: 5.2%
   ⚠️  POTENTIAL MEMORY LEAK DETECTED
      Projected growth: 376.1 MB/day

⚠️  TEST COMPLETED WITH WARNINGS
   Memory leak detected - review trend data
```

## System Requirements

### Required
- **Python 3.8+**
- **Working Nyx runtime** (`nyx_runtime.py`)
- **CPU:** Any modern CPU (tested on i7 12th gen)

### Recommended
- **psutil:** For full monitoring (`pip install psutil`)
  - Without psutil: Limited monitoring (no CPU temp, basic stats only)

### Hardware Notes

**i7 12th gen (Alder Lake):**
- 12-16 cores (P+E cores)
- Safe to run 24-32 workers
- Typical temps: 40-70°C under load
- Test will throttle at 85°C (safe margin below thermal limit)

**No hardware damage possible:**
- Modern CPUs have thermal throttling
- Test monitors and respects limits
- Automatic idle on overheat
- Graceful shutdown on any issue

## Advanced Usage

### Custom Duration (e.g., 30 minutes)

Edit `test_thermal_soak.py`:

```python
TEST_DURATION = 30 * 60  # 30 minutes
```

### Custom Worker Count

```python
MAX_WORKERS = 16  # Fixed worker count
```

### Disable Crash Injection

```python
injector = CrashInjector(enabled=False)
```

### Change Snapshot Interval (e.g., every 2 minutes)

```python
SNAPSHOT_INTERVAL = 2 * 60  # 2 minutes
```

### Custom Engines to Test

```python
engines = [
    'nycore', 'nydata', 'nycache',  # Your specific engines
]
```

## Troubleshooting

### Test Exits Immediately

**Cause:** `nyx_runtime.py` not found or not working

**Fix:**
```bash
# Verify runtime works
python nyx_runtime.py -c "print(42)"
```

### "psutil not installed" Warning

**Not critical** - Test still runs with limited monitoring.

**To enable full monitoring:**
```bash
pip install psutil
```

### High Failure Rate

**Cause:** Engines may have real issues or timeouts too aggressive

**Check:**
1. Run single engine test: `python nyx_runtime.py -c "use nycore"`
2. Increase timeout in `CrashInjector` if needed
3. Review failed engine logs

### CPU Overheating

**Automatic protection active!**

Test will show:
```
⚠️  WARNING: CPU temperature at 86°C - Forcing IDLE
```

**What to do:**
1. Let test continue (it will auto-throttle)
2. Check laptop cooling/fans
3. Consider reducing `MAX_WORKERS` by 50%

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Thermal Soak Test

on:
  schedule:
    - cron: '0 2 * * 0'  # Weekly on Sunday 2 AM

jobs:
  thermal-soak:
    runs-on: ubuntu-latest
    timeout-minutes: 150  # 2.5 hours
    
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      
      - run: pip install psutil
      - run: python tests/engines/test_thermal_soak.py
      
      - name: Upload logs
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: thermal-soak-logs
          path: tests/engines/thermal_soak_log.json
```

## FAQ

**Q: Will this damage my CPU?**  
A: No. Modern CPUs have built-in thermal protection. The test also has software limits (85°C) well below hardware limits (~100°C).

**Q: Can I stop the test early?**  
A: Yes. Press `Ctrl+C` for graceful shutdown. Current results will be saved.

**Q: What if I don't have 2 hours?**  
A: Edit `TEST_DURATION = 30 * 60` for a 30-minute test. Less reliable for leak detection but still useful.

**Q: Why burst + idle pattern?**  
A: Idle periods expose bugs that only appear when load changes (thread cleanup, deferred frees, pool shrinking).

**Q: How accurate is leak detection?**  
A: Very accurate with amplified load. A 1MB/hour leak becomes ~5-10MB in 2 hours, well above noise.

**Q: Can I run this on a VM?**  
A: Yes, but CPU temperature monitoring may not work (depends on hypervisor).

---

**Status:** Ready for production use  
**Version:** 1.0  
**Tested on:** i7 12th gen, Windows 11, Python 3.13
