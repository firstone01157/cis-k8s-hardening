#!/usr/bin/env python3
"""
Simple test script for reference resolution in cis_config.json
Tests that all variable references are correctly resolved at runtime
"""
import json
import sys
from pathlib import Path

# Read config directly
config_path = Path(__file__).parent / "cis_config.json"

with open(config_path) as f:
    config = json.load(f)

variables = config.get("variables", {})
checks = config.get("remediation_config", {}).get("checks", {})

print("=" * 70)
print("REFERENCE RESOLUTION VALIDATION")
print("=" * 70)

def get_nested_value(data, dotted_path):
    """Retrieve value using dotted path notation"""
    try:
        keys = dotted_path.split('.')
        current = data
        
        for key in keys:
            if isinstance(current, dict) and key in current:
                current = current[key]
            else:
                return None
        
        return current
    except Exception:
        return None


# Test the 6 specific checks
test_checks = {
    "1.2.8": {
        "expected_value": "6443",
        "description": "Secure port"
    },
    "1.2.14": {
        "expected_value": "300s",
        "description": "Request timeout"
    },
    "1.2.17": {
        "expected_value": "/registry",
        "description": "etcd prefix"
    },
    "1.2.20": {
        "expected_value": "VersionTLS12",
        "description": "TLS min version"
    },
    "1.2.23": {
        "expected_value": "/etc/kubernetes/audit-policy.yaml",
        "description": "Audit policy file"
    },
    "1.2.30": {
        "expected_value": "1h",
        "description": "Event TTL"
    }
}

print("\nTesting 6 Specific Checks:\n")
all_passed = True

for check_id, test_info in test_checks.items():
    if check_id not in checks:
        print(f"✗ Check {check_id} not found in config")
        all_passed = False
        continue
    
    check_config = checks[check_id]
    expected_value = test_info["expected_value"]
    description = test_info["description"]
    ref_key = "_required_value_ref"
    
    # Check if reference exists
    if ref_key not in check_config:
        print(f"✗ Check {check_id} ({description}): No reference key found")
        all_passed = False
        continue
    
    ref_path = check_config[ref_key]
    
    # Extract variable path (skip "variables." prefix)
    if ref_path.startswith("variables."):
        var_path = ref_path[len("variables."):]
        resolved_value = get_nested_value(variables, var_path)
    else:
        resolved_value = None
    
    # Type conversion for booleans
    if isinstance(resolved_value, bool):
        resolved_value = str(resolved_value).lower()
    
    if resolved_value is None:
        print(f"✗ Check {check_id} ({description}): Value not resolved")
        print(f"  Ref path: {ref_path}")
        all_passed = False
    elif resolved_value != expected_value:
        print(f"✗ Check {check_id} ({description}): Value mismatch")
        print(f"  Expected: {expected_value}")
        print(f"  Got:      {resolved_value}")
        all_passed = False
    else:
        print(f"✓ Check {check_id} ({description})")
        print(f"    Flag: {check_config.get('flag')}")
        print(f"    Resolved Value: {resolved_value}")

print("\n" + "=" * 70)
if all_passed:
    print("✓ ALL TESTS PASSED - References resolve correctly")
    sys.exit(0)
else:
    print("✗ SOME TESTS FAILED")
    sys.exit(1)
