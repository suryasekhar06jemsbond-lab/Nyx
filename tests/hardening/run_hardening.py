#!/usr/bin/env python3
"""Hardening gate for production-readiness modules."""

import sys
import unittest
from pathlib import Path


def main() -> int:
    # Determine root directory
    root = Path(__file__).resolve().parents[2]
    print("[hardening] Root directory: {}".format(root))
    
    # Add root to path
    if str(root) not in sys.path:
        sys.path.insert(0, str(root))
        print("[hardening] Added to sys.path: {}".format(root))
    
    # Check that tests directory exists
    tests_dir = root / "tests" / "hardening"
    if not tests_dir.exists():
        print("[hardening] ERROR: Tests directory not found: {}".format(tests_dir))
        return 1
    print("[hardening] Tests directory: {}".format(tests_dir))
    
    # Discover and run tests
    try:
        suite = unittest.defaultTestLoader.discover(str(tests_dir), pattern="test_*.py")
        print("[hardening] Discovered {} tests".format(suite.countTestCases()))
        result = unittest.TextTestRunner(verbosity=2).run(suite)
        return 0 if result.wasSuccessful() else 1
    except Exception as e:
        print("[hardening] ERROR during test discovery/execution: {}".format(e))
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
