#!/usr/bin/env python3
"""
Test script for reference resolution in cis_config.json
Tests that all variable references are correctly resolved at runtime
"""
import json
import sys
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent))

from cis_k8s_unified import CISUnifiedRunner


def test_reference_resolution():
    """Test that variable references are correctly resolved"""
    print("=" * 70)
    print("REFERENCE RESOLUTION TEST")
    print("=" * 70)
    
    # Initialize runner with verbose output
    runner = CISUnifiedRunner(verbose=1)
    
    print("\n" + "=" * 70)
    print("SPECIFIC CHECK VALIDATION")
    print("=" * 70)
    
    # Test the 6 specific checks that were updated
    test_checks = {
        "1.2.8": {
            "target_key": "_required_value",
            "expected_value": "6443",
            "description": "Secure port"
        },
        "1.2.14": {
            "target_key": "_required_value",
            "expected_value": "300s",
            "description": "Request timeout"
        },
        "1.2.17": {
            "target_key": "_required_value",
            "expected_value": "/registry",
            "description": "etcd prefix"
        },
        "1.2.20": {
            "target_key": "_required_value",
            "expected_value": "VersionTLS12",
            "description": "TLS min version"
        },
        "1.2.23": {
            "target_key": "_required_value",
            "expected_value": "/etc/kubernetes/audit-policy.yaml",
            "description": "Audit policy file"
        },
        "1.2.30": {
            "target_key": "_required_value",
            "expected_value": "1h",
            "description": "Event TTL"
        }
    }
    
    all_passed = True
    
    for check_id, test_info in test_checks.items():
        if check_id not in runner.remediation_checks_config:
            print(f"\n✗ Check {check_id} not found in config")
            all_passed = False
            continue
        
        check_config = runner.remediation_checks_config[check_id]
        target_key = test_info["target_key"]
        expected_value = test_info["expected_value"]
        description = test_info["description"]
        
        # Check if target_key exists (after resolution)
        resolved_value = check_config.get(target_key)
        
        if resolved_value is None:
            print(f"\n✗ Check {check_id} ({description}): {target_key} not resolved")
            print(f"  Config keys: {list(check_config.keys())}")
            all_passed = False
        elif resolved_value != expected_value:
            print(f"\n✗ Check {check_id} ({description}): Value mismatch")
            print(f"  Expected: {expected_value}")
            print(f"  Got:      {resolved_value}")
            all_passed = False
        else:
            print(f"\n✓ Check {check_id} ({description})")
            print(f"  Flag: {check_config.get('flag')}")
            print(f"  Value: {resolved_value}")
            print(f"  Ref:   {check_config.get('_required_value_ref')}")
    
    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)
    
    if all_passed:
        print("✓ All reference resolutions PASSED")
        return 0
    else:
        print("✗ Some reference resolutions FAILED")
        return 1


if __name__ == "__main__":
    exit_code = test_reference_resolution()
    sys.exit(exit_code)
