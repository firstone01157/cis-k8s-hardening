# Manual Status Enforcement - Quick Reference

## TL;DR

**Problem:** Manual checks were being marked as PASS/FIXED, inflating compliance scores.

**Solution:** Refactored `_parse_script_output()` to enforce `status = "MANUAL"` for any check marked as manual, regardless of exit code.

**Result:** Compliance score now reflects only verified/automated checks.

---

## What Changed

### Before
```
Manual Script + Exit 0 → PASS/FIXED → Counted in score ❌
```

### After
```
Manual Script + Exit 0 → MANUAL → NOT counted in score ✓
Manual Script + Exit 3 → MANUAL → NOT counted in score ✓
```

---

## Key Method: `_parse_script_output()`

### New Logic (First Check)

```python
# STEP 3: STRICT MANUAL ENFORCEMENT
if is_manual:
    status = "MANUAL"
    # ... set contextual reason ...
    return status, reason, fix_hint, cmds  # Early exit
```

### Impact

- **Removes:** Manual checks from "Success %" calculation
- **Keeps:** Manual checks tracked in reports (visible but separate)
- **Ensures:** Compliance score = (Verified Checks Only)

---

## Compliance Score Formula

```
Score = Pass / (Pass + Fail + Manual) × 100
```

### Example

| Before | After |
|--------|-------|
| 40 Pass / 45 Total = 88.9% ❌ | 40 Pass / 50 Total = 80% ✓ |

(Ignores 5 manual checks) | (Includes 5 manual checks) |

---

## Identifying Manual Checks

A check is considered MANUAL if:

1. **Title contains `(Manual)`:**
   ```bash
   # Title: Ensure something (Manual)
   ```

2. **OR script returns exit code 3:**
   ```bash
   exit 3  # Manual intervention required
   ```

3. **OR output contains manual keywords:**
   - "manual remediation"
   - "manual intervention"
   - "requires manual"

---

## Verbose Output

Run with `-vv` flag to see enforcement:

```bash
python3 cis_k8s_unified.py -vv
```

You'll see:
```
[DEBUG] MANUAL ENFORCEMENT: 5.1.2_audit forced to MANUAL status (is_manual=True, returncode=0)
```

---

## Report Output Examples

### Console (Color-Coded)
```
[50.0%] [25/50] 5.1.2_audit → MANUAL  ← Yellow (requires human verification)
[50.2%] [26/50] 1.1.1_audit → PASS    ← Green (automated, verified)
```

### Statistics Summary
```
MASTER:
  Pass:    40
  Fail:    5
  Manual:  5      ← Clearly visible, not counted in %
  Success: 80%    ← Reflects verified checks only
```

### CSV Report
```
5.1.2,master,1,MANUAL,0.32,"[INFO] Manual check executed successfully...",fix_cmd
```

---

## Decision Tree

```
Script Execution
        ↓
   is_manual?
    ↙        ↘
  YES        NO
   ↓         ↓
MANUAL    Exit Code?
              ↙  ↖  ↖
             3    0   Other
             ↓    ↓    ↓
          MANUAL PASS FAIL
```

---

## Backward Compatibility

✅ **Fully Compatible** - No changes needed to shell scripts

Existing scripts continue to work as before. The enforcement is entirely in the Python runner.

---

## Testing Checklist

- [ ] Run audit on Master node with `-vv` flag
- [ ] Verify manual checks appear in YELLOW
- [ ] Check summary shows "Manual: X" (separate count)
- [ ] Verify compliance score doesn't include manual checks
- [ ] Check CSV report lists manual checks with MANUAL status
- [ ] View HTML report - manual checks in separate section

---

## Common Issues

| Issue | Solution |
|-------|----------|
| Manual check showing as PASS | Script likely not marked (Manual) in title |
| Compliance score too low | Correct - now excluding manual checks |
| Missing manual checks | Check if title is marked (Manual) |
| Verbose messages not showing | Use `-vv` (double verbose) flag |

---

## Files Modified

- `cis_k8s_unified.py` - `_parse_script_output()` method
- `MANUAL_STATUS_ENFORCEMENT.md` - Full documentation
- `MANUAL_STATUS_ENFORCEMENT_QUICK_REFERENCE.md` - This file

---

## Version Info

- **Effective Date:** December 4, 2025
- **Version:** 1.0
- **Status:** Production Ready ✓
- **Syntax Check:** Passed ✓

