#!/usr/bin/env python3
"""Test activity logging functionality"""
import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

from cis_k8s_unified import CISUnifiedRunner
import time

# Create runner instance
runner = CISUnifiedRunner(verbose=False)

# Test logging
print(f"Log file: {runner.log_file}")
print(f"Log directory exists: {os.path.exists(os.path.dirname(runner.log_file))}")

# Log some test activities
runner.log_activity("TEST_START", "Testing logging functionality")
time.sleep(0.5)
runner.log_activity("TEST_ACTION", "First test action")
runner.log_activity("TEST_ACTION", "Second test action - Level:1, Role:master")
time.sleep(0.5)
runner.log_activity("TEST_END", "Testing completed successfully")

# Read and display log file
print("\n" + "="*60)
print("Log file contents:")
print("="*60)
if os.path.exists(runner.log_file):
    with open(runner.log_file, 'r') as f:
        print(f.read())
    print(f"\n✅ Logging test PASSED!")
else:
    print(f"❌ Log file not found: {runner.log_file}")
