# CIS Kubernetes Hardening - Dual-Metric Scoring Guide

## Overview

The `cis_k8s_unified.py` runner has been updated with a **dual-metric compliance scoring system** that provides accurate assessment of CIS hardening implementation.

**Status**: ✅ Production Ready  
**Version**: 2.0  
**Updated**: December 9, 2025

---

## The Problem: Single-Metric Scoring Was Flawed

### Original Approach (Before)
```
Score = Pass / (Pass + Fail + Manual) × 100%
```

**Problems**:
1. ❌ Manual checks (requiring human review) counted as **failures**, unfairly lowering the score
2. ❌ Conflated two different concerns: script automation vs. policy compliance
3. ❌ Misleading to operators (good scripts could look bad due to manual requirements)
4. ❌ Unhelpful for both DevOps (script issues) and auditors (compliance status)

**Example**:
```
Results: 20 PASS, 0 FAIL, 10 MANUAL
Old Score: 20 / (20 + 0 + 10) = 66.7% ❌ (Looks bad!)
```

---

## The Solution: Dual-Metric System

### Two Complementary Metrics

#### 1. AUTOMATION HEALTH (Technical Implementation)
```
Formula: Pass / (Pass + Fail)
Scope: ONLY automated checks (ignores manual)
Purpose: Measures if remediation scripts work correctly
Audience: DevOps/SRE engineers
Action: Fix broken remediation scripts
```

**Example**:
```
Results: 20 PASS, 2 FAIL, 10 MANUAL
Automation Health = 20 / (20 + 2) = 90.9% ✅
→ Scripts are working well; 2 need fixing
```

#### 2. AUDIT READINESS (Overall CIS Compliance)
```
Formula: Pass / Total Checks
Scope: ALL checks (manual counts as non-passing)
Purpose: Shows true CIS compliance status for formal audits
Audience: Security/Compliance teams, auditors
Action: Plan manual reviews and policy implementation
```

**Example**:
```
Results: 20 PASS, 2 FAIL, 10 MANUAL (total = 32)
Audit Readiness = 20 / 32 = 62.5%
→ 62.5% compliant; 10 need manual policy work, 2 have automation issues
```

---

## Output Format

### Console Display

```
======================================================================
COMPLIANCE STATUS: MASTER NODE
======================================================================

1. AUTOMATION HEALTH (Technical Implementation)
   [Pass / (Pass + Fail)]
   - Score: XX.XX%
   - Status: Excellent - Indicates how well the remediation scripts applied the config.

2. AUDIT READINESS (Overall CIS Compliance)
   [Pass / Total Checks]
   - Score: YY.YY%
   - Status: Good - Indicates readiness for a formal audit.

3. ACTION ITEMS
   - Automated Failures: 2  (Need script fixing)
   - Manual Reviews:     10  (Need human verification/policy)

======================================================================

DETAILED BREAKDOWN BY ROLE
======================================================================

  MASTER:
    Pass:         20
    Fail:          2
    Manual:       10
    Skipped:       0
    Total:        32
    Auto Health:  90.91%
    Audit Ready:  62.50%

  WORKER:
    (if applicable)
```

### Status Colors

| Score Range | Color | Status |
|-------------|-------|--------|
| **90-100%** | 🟢 Green | Excellent |
| **80-89%** | 🟢 Green | Good |
| **70-79%** | 🟡 Yellow | Acceptable |
| **50-69%** | 🟡 Yellow | Needs Improvement |
| **<50%** | 🔴 Red | Critical |

---

## Implementation Details

### Function: `calculate_compliance_scores(stats)`

**Purpose**: Compute both metrics from runner statistics

**Input**:
```python
stats = {
    "master": {
        "pass": 20,      # Passing checks
        "fail": 2,       # Failing checks
        "manual": 10,    # Checks requiring manual review
        "skipped": 0,    # Skipped checks
        "error": 0,      # Checks with errors
        "total": 32      # Total checks
    },
    "worker": { ... }    # Same structure for worker nodes
}
```

**Output**:
```python
{
    'automation_health': 90.91,      # Pass / (Pass + Fail)
    'audit_readiness': 62.50,        # Pass / Total
    'pass': 20,
    'fail': 2,
    'manual': 10,
    'skipped': 0,
    'error': 0,
    'total': 32
}
```

**Algorithm**:
```python
def calculate_compliance_scores(stats):
    # Aggregate across all roles (master, worker)
    total_pass = master_pass + worker_pass
    total_fail = master_fail + worker_fail
    total_manual = master_manual + worker_manual
    total_all = master_total + worker_total
    
    # METRIC 1: How well are scripts working?
    automated_checks = total_pass + total_fail
    automation_health = (total_pass / automated_checks) * 100
    
    # METRIC 2: What's our true compliance status?
    audit_readiness = (total_pass / total_all) * 100
    
    return {
        'automation_health': automation_health,
        'audit_readiness': audit_readiness,
        ...
    }
```

### Function: `print_stats_summary()`

**Purpose**: Display formatted compliance report

**Features**:
- ✅ Shows both metrics clearly labeled
- ✅ Color-coded scores based on ranges
- ✅ Per-role breakdown for transparency
- ✅ Action items section showing what to fix
- ✅ Status descriptions explaining each metric

**Output Sections**:
1. **Main Header**: "COMPLIANCE STATUS: MASTER NODE" (or WORKER, or CLUSTER)
2. **Automation Health**: Script effectiveness metric
3. **Audit Readiness**: True compliance metric
4. **Action Items**: Specific numbers needing attention
5. **Detailed Breakdown**: Per-role statistics

---

## Interpretation Guide

### Scenario 1: Excellent Automation, Good Compliance

```
AUTOMATION HEALTH: 98% (Excellent)
AUDIT READINESS: 85% (Good)

Interpretation:
✓ Remediation scripts are working almost perfectly
✓ Only a few checks failing due to policy/manual requirements
✓ Good candidate for production hardening
```

### Scenario 2: Good Automation, Poor Compliance

```
AUTOMATION HEALTH: 85% (Good)
AUDIT READINESS: 45% (Critical)

Interpretation:
✓ Scripts are mostly working
✗ Many checks require manual review/policy work
⚠ Need policy team to implement manual requirements
→ Not ready for formal audit until manual work is done
```

### Scenario 3: Poor Automation, Declining Compliance

```
AUTOMATION HEALTH: 30% (Critical)
AUDIT READINESS: 25% (Critical)

Interpretation:
✗ Remediation scripts are broken (many failures)
✗ Overall compliance is critically low
→ Fix script bugs first, then address manual items
→ Not suitable for production deployment
```

### Scenario 4: All Manual Checks

```
AUTOMATION HEALTH: 0% (No automated checks)
AUDIT READINESS: 45% (Critical)

Interpretation:
→ No automated checks run (all manual)
→ Compliance depends entirely on policy implementation
→ Scripts not providing remediation automation
```

---

## Use Cases

### 1. For DevOps/SRE Teams

**Focus on**: AUTOMATION HEALTH

```
"We have 95% automation health. Let's fix the 2 failing scripts
and we'll have a robust automated hardening system."
```

**Actions**:
- Investigate failing automated checks
- Fix script bugs or configuration issues
- Test remediation scripts in dev/staging
- Deploy to production

### 2. For Security/Compliance Teams

**Focus on**: AUDIT READINESS

```
"We have 72% audit readiness. The 10 manual checks represent
policies we need to document and implement."
```

**Actions**:
- Review manual check requirements
- Implement missing policies
- Document compliance controls
- Prepare for formal audit

### 3. For Auditors

**Both Metrics Matter**:

```
Automation Health = 90% → Scripts are reliable
Audit Readiness = 65% → 65% of controls are currently passing

"The 90% automation health shows technical implementation is sound.
The 65% audit readiness shows we need work on manual controls."
```

---

## Integration with Existing Code

### Backwards Compatibility

The old `calculate_score()` function still works:

```python
# Old usage (still supported)
score = runner.calculate_score(stats)  # Returns automation_health

# New usage (recommended)
scores = runner.calculate_compliance_scores(stats)
automation_health = scores['automation_health']
audit_readiness = scores['audit_readiness']
```

### Trend Analysis

The trend analysis feature now uses AUTOMATION HEALTH (more stable metric):

```python
# Compares automation health across runs
previous_health = 92.0
current_health = 95.5
trend = "✓ Improved by 3.5%"
```

### Reporting

All reports (CSV, JSON, HTML) now include both metrics:

```json
{
  "compliance_scores": {
    "automation_health": 90.91,
    "audit_readiness": 62.50,
    "details": {
      "pass": 20,
      "fail": 2,
      "manual": 10,
      "total": 32
    }
  }
}
```

---

## Example Workflow

### Week 1: Initial Assessment

```bash
python3 cis_k8s_unified.py --audit

Output:
AUTOMATION HEALTH: 75% (Needs Improvement)
AUDIT READINESS: 45% (Critical)

Action: "Many scripts are failing. First, fix automation issues."
```

### Week 2: Script Fixes

```bash
# Fix failing remediation scripts
# Test in dev environment
# Redeploy to production

python3 cis_k8s_unified.py --audit

Output:
AUTOMATION HEALTH: 95% (Excellent) ↑ 20%
AUDIT READINESS: 50% (Critical) ↑ 5%

Action: "Great! Scripts are working. Now focus on manual policies."
```

### Week 3: Policy Implementation

```bash
# Implement manual controls
# Document compliance evidence
# Test policies

python3 cis_k8s_unified.py --audit

Output:
AUTOMATION HEALTH: 95% (Excellent) → Stable
AUDIT READINESS: 85% (Good) ↑ 35%

Action: "Ready for formal CIS audit!"
```

---

## Technical Details

### Score Calculation Edge Cases

#### Case 1: No Automated Checks
```
Pass: 0, Fail: 0, Manual: 20
Automation Health = undefined (0/0)
→ Defaults to 0.0%
Audit Readiness = 0 / 20 = 0%
```

#### Case 2: No Checks Run
```
All counts: 0
Both metrics = 0.0%
Status: "No checks executed"
```

#### Case 3: Only Passing Checks
```
Pass: 50, Fail: 0, Manual: 0
Automation Health = 50 / 50 = 100%
Audit Readiness = 50 / 50 = 100%
```

### Per-Role Breakdown

Individual metrics are calculated per role (Master, Worker):

```python
master_auto_health = master_pass / (master_pass + master_fail)
master_audit_ready = master_pass / master_total

worker_auto_health = worker_pass / (worker_pass + worker_fail)
worker_audit_ready = worker_pass / worker_total
```

Cluster-wide metrics aggregate all roles:

```python
cluster_auto_health = total_pass / (total_pass + total_fail)
cluster_audit_ready = total_pass / total_all
```

---

## Migration Guide (If Updating Existing Code)

### If You Have Custom Scoring Logic

**Before**:
```python
score = self.calculate_score(self.stats)
if score > 80:
    print("Good compliance!")
```

**After**:
```python
scores = self.calculate_compliance_scores(self.stats)
auto_health = scores['automation_health']
audit_ready = scores['audit_readiness']

if auto_health > 80:
    print("Good automation health!")
if audit_ready > 80:
    print("Ready for audit!")
```

### If You Display the Score

**Before**:
```python
print(f"Compliance Score: {score}%")
```

**After**:
```python
scores = self.calculate_compliance_scores(self.stats)
print(f"Automation Health: {scores['automation_health']}%")
print(f"Audit Readiness: {scores['audit_readiness']}%")
```

---

## FAQ

**Q: Which metric is more important?**
A: Depends on your focus. DevOps cares about automation health; auditors care about audit readiness.

**Q: Why ignore manual checks in automation health?**
A: Because scripts can't fix policy decisions. Manual checks aren't automation failures.

**Q: Can a check be both passing and manual?**
A: No. Status is mutually exclusive: PASS, FAIL, MANUAL, SKIPPED, or ERROR.

**Q: What if I only care about the old score?**
A: Use `calculate_score()` which returns automation_health. Full backwards compatibility.

**Q: How do I improve audit readiness?**
A: Implement the manual checks (policy, documentation, etc.). They're not broken scripts.

**Q: How do I improve automation health?**
A: Fix the failing automated checks (script bugs, configuration issues, etc.).

---

## Summary

The dual-metric system provides:

✅ **Clear accountability**: Separates technical issues (automation) from policy issues (manual)
✅ **Better insights**: Two metrics tell a more complete story than one
✅ **Actionable guidance**: Different teams know what to focus on
✅ **Accurate compliance**: Audit readiness reflects true CIS status
✅ **Backwards compatible**: Old code still works

**Result**: Better hardening outcomes and more productive team discussions.

---

**Document Version**: 1.0  
**Updated**: December 9, 2025  
**Status**: ✅ Current
