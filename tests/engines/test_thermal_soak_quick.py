#!/usr/bin/env python3
"""
Quick 1-minute validation of thermal soak test
"""
import sys
import os

# Temporarily modify duration for quick test
original_file = 'tests/engines/test_thermal_soak.py'

with open(original_file, 'r', encoding='utf-8') as f:
    content = f.read()

# Quick test: 1 minute total, 20 second burst, 10 second idle
quick_content = content.replace(
    "TEST_DURATION = 2 * 60 * 60  # 2 hours in seconds",
    "TEST_DURATION = 1 * 60  # 1 minute in seconds"
).replace(
    "BURST_DURATION = 10 * 60  # 10 minutes",
    "BURST_DURATION = 20  # 20 seconds"
).replace(
    "IDLE_DURATION = 5 * 60  # 5 minutes",
    "IDLE_DURATION = 10  # 10 seconds"
).replace(
    "SNAPSHOT_INTERVAL = 5 * 60  # 5 minutes",
    "SNAPSHOT_INTERVAL = 15  # 15 seconds"
)

# Execute modified version
exec(compile(quick_content, original_file, 'exec'))
