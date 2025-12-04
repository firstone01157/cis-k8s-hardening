# Manual Status Enforcement - Implementation Guide

## Overview

**Date:** December 4, 2025  
**Version:** 1.0  
**Affected Method:** `_parse_script_output()` in `CISUnifiedRunner` class

---

## Problem Statement

Previously, when manual remediation scripts executed successfully (exit code 0), the runner would incorrectly mark them as `PASS` or `FIXED`, inflating the compliance score. This was problematic because:

1. **Inflated Compliance Scores:** Manual checks should NOT count toward the success percentage
2. **False Sense of Security:** Users might think 100% compliance was achieved when many checks require human verification
3. **Misleading Reports:** Reports would show high scores without acknowledging manual intervention points

### Example of Previous Behavior
```
Check: 1.2.1 (Manual)
Script Exit Code: 0 (success)
PREVIOUS Result: "PASS" ✓ (WRONG - counted in score)
NEW Result: "MANUAL" ⚠ (CORRECT - requires human verification)
```

---

## Solution: Strict Manual Enforcement

The refactored `_parse_script_output()` method now implements **STEP 3: STRICT MANUAL ENFORCEMENT** which:

1. **Checks the `is_manual` parameter first** (top of decision tree)
2. **Forces `status = "MANUAL"` unconditionally** if `is_manual=True`
3. **Returns immediately** to bypass any success/failure logic
4. **Never allows manual checks to become PASS/FIXED** regardless of exit code

---

## Algorithm Flow

### New Decision Tree (FIFO Priority)

```
Input: result, script_id, mode, is_manual

│
├─ STEP 3: STRICT MANUAL ENFORCEMENT
│  ├─ IF is_manual == True
│  │  ├─ Set status = "MANUAL"
│  │  ├─ Set reason (context-aware based on exit code)
│  │  └─ RETURN (early exit - no further processing)
│  │
│  └─ ELSE: Continue to normal processing
│
├─ STEP 4: PRIORITY 1 - Exit Code 3
│  ├─ IF returncode == 3
│  │  ├─ Set status = "MANUAL"
│  │  └─ Set reason = "[INFO] Script returned exit code 3..."
│  │
│  └─ ELSE: Continue
│
├─ STEP 5: PRIORITY 2 - Exit Code 0 (Success)
│  ├─ IF returncode == 0
│  │  ├─ IF mode == "remediate"
│  │  │  └─ status = "FIXED" or "PASS"
│  │  └─ ELSE (audit mode)
│  │     └─ status = "PASS"
│  │
│  └─ ELSE: Continue
│
├─ STEP 6: PRIORITY 3 - Fallback Detection
│  ├─ IF returncode != 0 (non-zero failure)
│  │  ├─ IF mode == "audit" AND (is_manual_check keyword found)
│  │  │  └─ status = "MANUAL"
│  │  └─ ELSE
│  │     └─ status = "FAIL"
│  │
│  └─ Return result
```

### Key Differences from Previous Implementation

| Aspect | Previous | New |
|--------|----------|-----|
| **Manual Check Handling** | Treated after exit codes | Checked FIRST (early exit) |
| **Exit Code 0 + Manual** | Could become PASS/FIXED | Always becomes MANUAL |
| **Decision Order** | Exit codes → Manual detection | Manual enforcement → Exit codes |
| **Compliance Score** | Manual checks counted ❌ | Manual checks excluded ✓ |

---

## Code Implementation

### STEP 3: Strict Manual Enforcement (New)

```python
# ========== STEP 3: STRICT MANUAL ENFORCEMENT ==========
if is_manual:
    status = "MANUAL"
    if not reason:
        # Provide context about script execution
        if result.returncode == 0:
            reason = "[INFO] Manual check executed successfully. Human verification required before marking as resolved."
        elif result.returncode == 3:
            reason = "[INFO] Script returned exit code 3 (Manual Intervention Required)"
        else:
            reason = "[INFO] Manual check requires human verification."
    
    if self.verbose >= 2:
        print(f"{Colors.BLUE}[DEBUG] MANUAL ENFORCEMENT: {script_id} forced to MANUAL status...")
    
    return status, reason, fix_hint, cmds  # EARLY EXIT
```

### Contextual Reason Messages

The method now provides **exit-code-aware reason messages** for manual checks:

| Exit Code | Reason Message |
|-----------|---------|
| `0` | "Manual check executed successfully. Human verification required before marking as resolved." |
| `3` | "Script returned exit code 3 (Manual Intervention Required)" |
| Other | "Manual check requires human verification." |

---

## Impact on Compliance Score

### Calculation Formula

```python
Score = (Pass Count) / (Pass + Fail + Manual) * 100
```

**Key Points:**
- MANUAL checks are **counted in the denominator** (they're tracked)
- MANUAL checks are **NOT counted in the numerator** (they don't contribute to "passed")
- This ensures the score reflects only **verified/automated checks**

### Example Scenario

**Audit Results:**
- 50 Total Checks
- 40 PASS (automated, verified)
- 5 FAIL
- 5 MANUAL (require human verification)

**Previous Score (INCORRECT):**
```
(40 PASS) / (40 + 5) = 88.9% ❌ (Ignores manual checks)
```

**New Score (CORRECT):**
```
(40 PASS) / (40 + 5 + 5) = 80.0% ✓ (Includes manual checks in denominator)
```

---

## Statistics Tracking

The `update_stats()` method already correctly handles MANUAL status:

```python
if status == "MANUAL":
    counter_key = "manual"
    self.stats[role]["manual"] += 1  # Tracked separately
    self.stats[role]["total"] += 1   # Included in total
```

**Report Output:**
```
MASTER:
  Pass:    40
  Fail:    5
  Manual:  5      ← Clearly visible
  Skipped: 0
  Total:   50
  Success: 80%    ← Accurately reflects verified checks
```

---

## Testing Scenarios

### Test Case 1: Manual Audit Script with Exit 0

**Script:** `Level_1_Master_Node/5.1.2_audit.sh`  
**Title:** "Minimize access to secrets (Manual)"  
**Exit Code:** 0 (successful execution)

**Expected Behavior:**
```
BEFORE: status = "PASS" ❌ (Wrong - added to score)
AFTER:  status = "MANUAL" ✓ (Correct - requires verification)
```

### Test Case 2: Manual Remediation Script with Exit 0

**Script:** `Level_1_Worker_Node/4.2.4_remediate.sh`  
**Title:** "Verify readOnlyPort is set to 0 (Manual)"  
**Exit Code:** 0 (changes applied)

**Expected Behavior:**
```
BEFORE: status = "FIXED" ❌ (Wrong - inflated score)
AFTER:  status = "MANUAL" ✓ (Correct - human must verify)
```

### Test Case 3: Automated Script with Exit 0

**Script:** `Level_1_Master_Node/1.1.1_audit.sh`  
**Title:** "Ensure API server pod security policy"  
**Exit Code:** 0 (check passed)

**Expected Behavior:**
```
BEFORE: status = "PASS" ✓
AFTER:  status = "PASS" ✓ (Unchanged - not a manual check)
```

### Test Case 4: Script with Exit Code 3 (Manual Indicator)

**Script:** Any script that returns exit code 3  
**Exit Code:** 3 (indicating manual intervention required)

**Expected Behavior:**
```
BEFORE: status = "FAIL" ❌ (Wrong - counted as failure)
AFTER:  status = "MANUAL" ✓ (Correct - standardized manual exit)
```

---

## Debugging & Verbose Output

When running with verbose flag (`-vv`), you'll see debug messages:

```bash
$ python3 cis_k8s_unified.py -vv
```

**Output Example:**
```
[DEBUG] MANUAL ENFORCEMENT: 5.1.2_audit forced to MANUAL status (is_manual=True, returncode=0)
[DEBUG] Exit code 3 detected for 4.2.1_audit - Setting status to MANUAL
```

---

## Migration & Backward Compatibility

### For Existing Scripts

No changes needed to existing shell scripts. The enforcement is entirely in the Python runner.

### For Custom Scripts

If you have custom scripts that should be manual:

1. **Option A:** Add `(Manual)` to the title:
   ```bash
   # Title: Check something important (Manual)
   ```

2. **Option B:** Return exit code 3:
   ```bash
   exit 3  # Signals manual intervention required
   ```

3. **Option C:** Use both for double-assurance:
   ```bash
   # Title: Check something (Manual)
   ...
   exit 3
   ```

---

## Reports & Output

### Console Output

Manual checks display in **Yellow**:
```
[50.0%] [25/50] 5.1.2_audit → MANUAL
```

### CSV Report

```csv
id,role,level,status,duration,reason,fix_hint,component
5.1.2,master,1,MANUAL,0.32,"[INFO] Manual check executed successfully...","",rbac
```

### Summary Report

```
MASTER:
  Pass:    40
  Fail:    5
  Manual:  5      ← Clearly separated
  Skipped: 0
  Total:   50
  Success: 80%
```

### HTML Report

Manual checks appear in a distinct section with yellow highlight:
```html
<div class="stat-box manual">
  <div style="font-size: 24px;">5</div>Manual
</div>
```

---

## FAQ

**Q: Will this break my existing audit results?**  
A: No. The compliance score will be more accurate, but some existing manual checks may show different scores if previously counted as PASS.

**Q: Can I force a manual check to be counted as PASS?**  
A: Not through the runner. Manual checks require human verification by design. If you want to count it as verified, mark it with a different indicator in your script output.

**Q: What if my script is marked (Manual) but I want it to be automatic?**  
A: Remove `(Manual)` from the title in the shell script. Only checks with `(Manual)` in the title are enforced as MANUAL.

**Q: How do I verify a manual check so it counts in the score?**  
A: Manual verification is currently tracked externally. The MANUAL status indicates "requires human review." You can:
- Manually document verification in comments
- Create a separate verification script
- Update documentation with verification timestamps

**Q: What if is_manual flag is True but the script exits with 3?**  
A: The `is_manual=True` condition is checked first, so status becomes MANUAL immediately. The exit code 3 is noted in the reason but doesn't override the status.

---

## Verification Command

To verify the enforcement is working:

```bash
# Run audit with verbose output
python3 cis_k8s_unified.py -vv

# Select: 1) Audit only
# Select: 1) Master only  
# Select: 3) All

# Look for MANUAL checks in output (yellow colored)
# Verify compliance score excludes them
```

---

## Summary

| Aspect | Details |
|--------|---------|
| **Feature** | Strict Manual Status Enforcement |
| **Location** | `cis_k8s_unified.py` - `_parse_script_output()` method |
| **Key Change** | Manual checks forced to MANUAL status regardless of exit code |
| **Impact** | Compliance scores now reflect only verified/automated checks |
| **Backward Compatible** | Yes - existing scripts work unchanged |
| **Testing** | Use `-vv` verbose flag to see enforcement messages |

---

**Last Updated:** December 4, 2025  
**Status:** Production Ready ✓  
**Syntax Checked:** ✓ No errors found

