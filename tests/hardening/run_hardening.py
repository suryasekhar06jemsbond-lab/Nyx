#!/usr/bin/env python3
"""Hardening gate for production-readiness modules."""

import sys
import unittest
from pathlib import Path


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    if str(root) not in sys.path:
        sys.path.insert(0, str(root))
    
    # Use absolute path for test discovery to work in any directory
    tests_dir = root / "tests" / "hardening"
    suite = unittest.defaultTestLoader.discover(str(tests_dir), pattern="test_*.py")
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(main())
