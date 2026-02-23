#!/usr/bin/env python3
"""Hardening gate for production-readiness modules."""

import sys
import unittest
from pathlib import Path


def main() -> int:
    # Determine root directory
    root = Path(__file__).resolve().parents[2]
    print(f"[hardening] Root directory: {root}")
    
    # Add root to path
    if str(root) not in sys.path:
        sys.path.insert(0, str(root))
        print(f"[hardening] Added to sys.path: {root}")
    
    # Check that tests directory exists
    tests_dir = root / "tests" / "hardening"
    if not tests_dir.exists():
        print(f"[hardening] ERROR: Tests directory not found: {tests_dir}")
        return 1
    print(f"[hardening] Tests directory: {tests_dir}")
    
    # Discover and run tests
    try:
        suite = unittest.defaultTestLoader.discover(str(tests_dir), pattern="test_*.py")
        print(f"[hardening] Discovered {suite.countTestCases()} tests")
        result = unittest.TextTestRunner(verbosity=2).run(suite)
        return 0 if result.wasSuccessful() else 1
    except Exception as e:
        print(f"[hardening] ERROR during test discovery/execution: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
