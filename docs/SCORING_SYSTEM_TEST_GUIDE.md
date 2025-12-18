# Testing Guide: Dual-Metric Scoring System

## Overview

This guide provides practical methods to test the new dual-metric scoring implementation in `cis_k8s_unified.py`.

---

## Unit Testing

### Test 1: Perfect Compliance

**Scenario**: All checks passing, no failures or manual items.

```python
# Create test stats
test_stats = {
    "master": {
        "pass": 32, "fail": 0, "manual": 0, "skipped": 0, "error": 0, "total": 32
    },
    "worker": {
        "pass": 20, "fail": 0, "manual": 0, "skipped": 0, "error": 0, "total": 20
    }
}

# Expected results
# Total: 52 pass, 0 fail, 0 manual (52 total)
# Automation Health = 52 / (52 + 0) = 100.00%
# Audit Readiness = 52 / 52 = 100.00%
```

**Python Test**:
```python
def test_perfect_compliance():
    runner = CIS_K8S_Unified()
    scores = runner.calculate_compliance_scores(test_stats)
    
    assert scores['automation_health'] == 100.0, "Should be 100%"
    assert scores['audit_readiness'] == 100.0, "Should be 100%"
    print("✓ Test passed: Perfect compliance correctly calculated")
```

**Expected Output**:
```
AUTOMATION HEALTH: 100.00% ✅
AUDIT READINESS: 100.00% ✅
Status: Excellent
```

---

### Test 2: Mixed Pass/Fail/Manual

**Scenario**: Real-world situation with some passes, some failures, many manual.

```python
test_stats = {
    "master": {
        "pass": 18, "fail": 2, "manual": 12, "skipped": 0, "error": 0, "total": 32
    },
    "worker": {
        "pass": 15, "fail": 1, "manual": 4, "skipped": 0, "error": 0, "total": 20
    }
}

# Expected calculations
# Total: 33 pass, 3 fail, 16 manual (52 total)
# Automation Health = 33 / (33 + 3) = 33/36 = 91.67%
# Audit Readiness = 33 / 52 = 63.46%
```

**Python Test**:
```python
def test_mixed_results():
    runner = CIS_K8S_Unified()
    scores = runner.calculate_compliance_scores(test_stats)
    
    assert abs(scores['automation_health'] - 91.67) < 0.1, "Automation health mismatch"
    assert abs(scores['audit_readiness'] - 63.46) < 0.1, "Audit readiness mismatch"
    print("✓ Test passed: Mixed results correctly calculated")
```

---

### Test 3: All Manual (No Automation)

**Scenario**: All checks are manual (no automation implemented).

```python
test_stats = {
    "master": {
        "pass": 0, "fail": 0, "manual": 32, "skipped": 0, "error": 0, "total": 32
    },
    "worker": {
        "pass": 0, "fail": 0, "manual": 20, "skipped": 0, "error": 0, "total": 20
    }
}

# Expected calculations
# Total: 0 pass, 0 fail, 52 manual (52 total)
# Automation Health = 0 / (0 + 0) = UNDEFINED → 0.0%
# Audit Readiness = 0 / 52 = 0.00%
```

**Python Test**:
```python
def test_all_manual():
    runner = CIS_K8S_Unified()
    scores = runner.calculate_compliance_scores(test_stats)
    
    assert scores['automation_health'] == 0.0, "No automation should be 0%"
    assert scores['audit_readiness'] == 0.0, "No passing checks should be 0%"
    print("✓ Test passed: All-manual scenario handled correctly")
```

---

### Test 4: Broken Automation

**Scenario**: Automation implemented but many failures.

```python
test_stats = {
    "master": {
        "pass": 8, "fail": 15, "manual": 9, "skipped": 0, "error": 0, "total": 32
    },
    "worker": {
        "pass": 5, "fail": 10, "manual": 5, "skipped": 0, "error": 0, "total": 20
    }
}

# Expected calculations
# Total: 13 pass, 25 fail, 14 manual (52 total)
# Automation Health = 13 / (13 + 25) = 13/38 = 34.21%
# Audit Readiness = 13 / 52 = 25.00%
```

**Python Test**:
```python
def test_broken_automation():
    runner = CIS_K8S_Unified()
    scores = runner.calculate_compliance_scores(test_stats)
    
    assert abs(scores['automation_health'] - 34.21) < 0.1, "Broken automation detected"
    assert abs(scores['audit_readiness'] - 25.0) < 0.1, "Poor compliance detected"
    assert scores['automation_health'] < scores['audit_readiness'], "Unusual divergence"
    print("✓ Test passed: Broken automation correctly identified")
```

---

### Test 5: Zero Checks

**Scenario**: Edge case - no checks executed at all.

```python
test_stats = {
    "master": {
        "pass": 0, "fail": 0, "manual": 0, "skipped": 0, "error": 0, "total": 0
    },
    "worker": {
        "pass": 0, "fail": 0, "manual": 0, "skipped": 0, "error": 0, "total": 0
    }
}

# Expected calculations
# Total: 0 pass, 0 fail, 0 manual (0 total)
# Automation Health = undefined → 0.0%
# Audit Readiness = 0 / 0 = undefined → 0.0%
```

**Python Test**:
```python
def test_zero_checks():
    runner = CIS_K8S_Unified()
    scores = runner.calculate_compliance_scores(test_stats)
    
    assert scores['automation_health'] == 0.0, "Zero checks → 0%"
    assert scores['audit_readiness'] == 0.0, "Zero checks → 0%"
    print("✓ Test passed: Zero checks edge case handled")
```

---

## Integration Testing

### Test 6: Full Audit Run

**Scenario**: Run actual `--audit` and verify output format.

```bash
# Run the audit
python3 cis_k8s_unified.py --audit

# Verify output contains expected sections
# ✓ "AUTOMATION HEALTH"
# ✓ "AUDIT READINESS"
# ✓ "ACTION ITEMS"
# ✓ Scores with percentage signs
# ✓ Color codes (Green/Yellow/Red)
```

**Bash Test**:
```bash
#!/bin/bash

# Run audit and capture output
OUTPUT=$(python3 cis_k8s_unified.py --audit 2>&1)

# Check for required sections
if echo "$OUTPUT" | grep -q "AUTOMATION HEALTH"; then
    echo "✓ Automation Health section present"
else
    echo "✗ Missing Automation Health section"
    exit 1
fi

if echo "$OUTPUT" | grep -q "AUDIT READINESS"; then
    echo "✓ Audit Readiness section present"
else
    echo "✗ Missing Audit Readiness section"
    exit 1
fi

if echo "$OUTPUT" | grep -q "ACTION ITEMS"; then
    echo "✓ Action Items section present"
else
    echo "✗ Missing Action Items section"
    exit 1
fi

# Check for percentage scores
if echo "$OUTPUT" | grep -E "[0-9]+\.[0-9]+%"; then
    echo "✓ Percentage scores present"
else
    echo "✗ Missing percentage scores"
    exit 1
fi

echo "✓ Integration test passed"
```

---

### Test 7: Remediation Run

**Scenario**: Run `--remediate` and verify new scores.

```bash
# Run remediation
python3 cis_k8s_unified.py --remediate --dry-run

# Run audit to check improvement
python3 cis_k8s_unified.py --audit

# Verify automation health improved
```

**Expected Behavior**:
- Automation health should increase (more PASS, fewer FAIL)
- Audit readiness should improve (more total PASS)
- Manual checks should remain stable (not affected by remediation)

---

## Color Code Testing

### Test 8: Color Output

**Scenario**: Verify color codes display correctly.

```bash
# Run with different cluster sizes to trigger different scores
python3 cis_k8s_unified.py --audit

# Visual inspection:
# Green text (90%+): Excellent
# Green text (80-89%): Good
# Yellow text (50-79%): Needs Improvement
# Red text (<50%): Critical
```

**Bash Color Detection**:
```bash
#!/bin/bash

OUTPUT=$(python3 cis_k8s_unified.py --audit 2>&1)

# Check for ANSI color codes
if echo "$OUTPUT" | grep -q $'\033\[[0-9]*m'; then
    echo "✓ Color codes detected in output"
else
    echo "⚠ No color codes found (may be disabled)"
fi

# Check for Green (32m)
if echo "$OUTPUT" | grep -q $'\033\[32m'; then
    echo "✓ Green codes present"
fi

# Check for Yellow (33m)
if echo "$OUTPUT" | grep -q $'\033\[33m'; then
    echo "✓ Yellow codes present"
fi

# Check for Red (31m)
if echo "$OUTPUT" | grep -q $'\033\[31m'; then
    echo "✓ Red codes present"
fi
```

---

## Backwards Compatibility Testing

### Test 9: Old `calculate_score()` Function

**Scenario**: Verify old function still works.

```python
test_stats = {
    "master": {
        "pass": 18, "fail": 2, "manual": 12, "skipped": 0, "error": 0, "total": 32
    },
    "worker": {
        "pass": 15, "fail": 1, "manual": 4, "skipped": 0, "error": 0, "total": 20
    }
}

# Old function should return automation_health
old_score = runner.calculate_score(test_stats)
new_scores = runner.calculate_compliance_scores(test_stats)

# They should be equal
assert old_score == new_scores['automation_health'], "Backwards compatibility broken"
print(f"✓ Old function returns: {old_score}")
print(f"✓ Matches automation_health: {new_scores['automation_health']}")
```

---

## Performance Testing

### Test 10: Large Statistics Set

**Scenario**: Verify scoring works with large datasets.

```python
import time

# Create large dataset (1000 roles)
large_stats = {f"role_{i}": {
    "pass": 100 + i,
    "fail": 10 + (i % 5),
    "manual": 20 + (i % 10),
    "skipped": 5,
    "error": 0,
    "total": 150 + (i % 15)
} for i in range(1000)}

# Measure performance
start = time.time()
scores = runner.calculate_compliance_scores(large_stats)
elapsed = time.time() - start

print(f"✓ Processed 1000 roles in {elapsed:.3f} seconds")
assert elapsed < 0.1, "Performance regression detected"
```

---

## Test Execution Script

Create a comprehensive test file:

```bash
#!/bin/bash
# tests/test_scoring_system.sh

set -e

echo "================================"
echo "Testing Dual-Metric Scoring"
echo "================================"

# Test 1: Perfect Compliance
echo -e "\n[Test 1] Perfect Compliance..."
python3 -c "
import sys
sys.path.insert(0, '/home/first/Project/cis-k8s-hardening')
from cis_k8s_unified import CIS_K8S_Unified

runner = CIS_K8S_Unified()
stats = {
    'master': {'pass': 32, 'fail': 0, 'manual': 0, 'skipped': 0, 'error': 0, 'total': 32},
    'worker': {'pass': 20, 'fail': 0, 'manual': 0, 'skipped': 0, 'error': 0, 'total': 20}
}

scores = runner.calculate_compliance_scores(stats)
assert scores['automation_health'] == 100.0
assert scores['audit_readiness'] == 100.0
print('✓ PASSED')
"

# Test 2: Mixed Results
echo -e "\n[Test 2] Mixed Pass/Fail/Manual..."
python3 -c "
import sys
sys.path.insert(0, '/home/first/Project/cis-k8s-hardening')
from cis_k8s_unified import CIS_K8S_Unified

runner = CIS_K8S_Unified()
stats = {
    'master': {'pass': 18, 'fail': 2, 'manual': 12, 'skipped': 0, 'error': 0, 'total': 32},
    'worker': {'pass': 15, 'fail': 1, 'manual': 4, 'skipped': 0, 'error': 0, 'total': 20}
}

scores = runner.calculate_compliance_scores(stats)
auto_health = scores['automation_health']
audit_ready = scores['audit_readiness']

# Automation Health: 33 / (33 + 3) = 91.67%
assert 91.5 < auto_health < 91.8, f'Got {auto_health}'
# Audit Readiness: 33 / 52 = 63.46%
assert 63.3 < audit_ready < 63.6, f'Got {audit_ready}'
print('✓ PASSED')
"

# Test 3: Edge Case - Zero Checks
echo -e "\n[Test 3] Edge Case: Zero Checks..."
python3 -c "
import sys
sys.path.insert(0, '/home/first/Project/cis-k8s-hardening')
from cis_k8s_unified import CIS_K8S_Unified

runner = CIS_K8S_Unified()
stats = {
    'master': {'pass': 0, 'fail': 0, 'manual': 0, 'skipped': 0, 'error': 0, 'total': 0},
    'worker': {'pass': 0, 'fail': 0, 'manual': 0, 'skipped': 0, 'error': 0, 'total': 0}
}

scores = runner.calculate_compliance_scores(stats)
assert scores['automation_health'] == 0.0
assert scores['audit_readiness'] == 0.0
print('✓ PASSED')
"

# Test 4: Backwards Compatibility
echo -e "\n[Test 4] Backwards Compatibility..."
python3 -c "
import sys
sys.path.insert(0, '/home/first/Project/cis-k8s-hardening')
from cis_k8s_unified import CIS_K8S_Unified

runner = CIS_K8S_Unified()
stats = {
    'master': {'pass': 18, 'fail': 2, 'manual': 12, 'skipped': 0, 'error': 0, 'total': 32},
    'worker': {'pass': 15, 'fail': 1, 'manual': 4, 'skipped': 0, 'error': 0, 'total': 20}
}

old_score = runner.calculate_score(stats)
new_scores = runner.calculate_compliance_scores(stats)
assert old_score == new_scores['automation_health']
print(f'✓ PASSED (score={old_score})')
"

echo -e "\n================================"
echo "All tests passed! ✓"
echo "================================"
```

---

## Production Testing Checklist

Before deploying to production:

- [ ] Unit tests pass (all 5 test cases)
- [ ] Integration test passes (audit run succeeds)
- [ ] Color codes display correctly
- [ ] Backwards compatibility verified
- [ ] Performance acceptable (<0.5s for stats calculation)
- [ ] Output format matches specification
- [ ] Per-role breakdown accurate
- [ ] Edge cases handled (zero checks, all manual, etc.)
- [ ] Documentation reflects actual behavior
- [ ] Trend analysis still works
- [ ] CSV/JSON export includes both metrics
- [ ] No regressions in existing functionality

---

## Troubleshooting

### Issue: Automation Health shows 0% but there are passing checks

**Cause**: All passing checks are manual (no automated checks exist)

**Fix**: This is expected behavior. Automation Health only considers automated checks.

### Issue: Audit Readiness shows very low despite good automation health

**Cause**: Many manual checks not yet implemented

**Fix**: This is expected. Implement the manual checks to improve audit readiness.

### Issue: Scores differ slightly from manual calculation

**Cause**: Floating-point precision or rounding

**Fix**: Use `abs(score1 - score2) < 0.1` for comparisons, not exact equality.

### Issue: Color codes not appearing in output

**Cause**: Terminal doesn't support ANSI color codes

**Fix**: Either use a color-capable terminal or disable colors via environment variable.

---

## Summary

The testing guide covers:
- ✅ Unit tests for all calculation scenarios
- ✅ Integration tests with actual audit runs
- ✅ Edge case handling
- ✅ Backwards compatibility verification
- ✅ Performance validation
- ✅ Color code verification
- ✅ Production readiness checklist

**Status**: Ready to test and deploy.

---

**Document Version**: 1.0  
**Updated**: December 9, 2025  
**Status**: ✅ Complete
