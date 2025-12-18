# MANUAL CHECKS - QUICK REFERENCE CARD

**Version:** 1.0  
**Date:** December 17, 2025  
**Status:** ✅ Production Ready

---

## 🎯 What Changed?

MANUAL checks (items requiring human decisions) are now:
- **Skipped** during automation
- **Tracked separately** in `manual_pending_items[]`
- **Excluded** from automation health scores
- **Displayed** in dedicated summary section
- **No longer** treated as failures

---

## 📊 Score Changes

### Before
```
Automation Health = 20/(20+5+8) = 52.6% ❌ Penalizes MANUAL items
Audit Readiness  = 20/(20+5+8) = 52.6% ❌ Penalizes MANUAL items
```

### After
```
Automation Health = 20/(20+5) = 80% ✅ Shows script effectiveness
Audit Readiness  = 20/(20+5) = 80% ✅ Shows true compliance
MANUAL Items     = 8 items (tracked separately) 🔍
```

---

## 🔍 How MANUAL is Detected

**3-Point Detection (in order):**

1. **Config Check**
   ```json
   {"remediation": "manual"}  // in cis_config.json
   ```

2. **Audit Result Check**
   ```python
   status == 'MANUAL'  // from previous audit
   ```

3. **Script Content Check**
   ```bash
   # Contains "MANUAL" marker in script file
   ```

**Any match = MANUAL check → Skip execution**

---

## 🚀 Execution Flow

```
For each check:
  ├─ Is it MANUAL? (3-point check)
  │  ├─ YES → Skip execution, add to manual_pending_items, continue
  │  └─ NO → Execute script, update stats
```

---

## 📋 MANUAL Section in Report

```
📋 MANUAL INTERVENTION REQUIRED
Items skipped from automation for human review:

Total: 8 checks require manual review

MASTER NODE (5 items):
  • 1.2.1: Requires cluster architecture decision
  • 2.1.1: Depends on backup strategy
  ...

WORKER NODE (3 items):
  • 4.1.1: Kubelet review required
  ...

Note: These are NOT failures or errors
Recommended Actions:
  1. Review each item
  2. Determine if applicable
  3. Implement if needed
  4. Re-run audit to verify
```

---

## 📈 Statistics

```python
self.stats = {
    'master': {
        'pass': 20,      # Passed automated checks
        'fail': 3,       # Failed automated checks
        'manual': 8,     # Skipped (MANUAL) ← Separate counter
        'skipped': 2,    # Not required
        'error': 1,      # Execution errors
        'total': 34      # Grand total
    }
}

# Important:
# Automation Health = pass / (pass + fail)  ← NO manual in calc
# Audit Readiness = pass / (pass + fail)    ← NO manual in calc
# Manual items = displayed separately in report
```

---

## ⚙️ Implementation Summary

| Component | Where | What |
|-----------|-------|------|
| **List** | `__init__` line 82 | `self.manual_pending_items = []` |
| **Reset** | Remediation start line 2146 | Reset on each run |
| **Detection GROUP A** | Lines 2164-2210 | 3-point check + skip |
| **Detection GROUP B** | Lines 2340-2385 | Pre-filter before parallel |
| **Report** | Lines 2600-2800 | New "📋 MANUAL" section |

---

## 🔧 How to Mark a Check as MANUAL

### Method 1: Config File
```json
{
  "checks": {
    "1.2.1": {
      "remediation": "manual"  ← Add this
    }
  }
}
```

### Method 2: Script Comment
```bash
#!/bin/bash
# MANUAL: This requires human decision because...
# Your code here...
```

### Method 3: From Audit
```python
# If marked MANUAL in previous audit,
# stays MANUAL in remediation
```

---

## ✅ What NOT to Worry About

- ✅ MANUAL items no longer lower Automation Health
- ✅ MANUAL items are not failures
- ✅ MANUAL items won't block automation
- ✅ MANUAL items are clearly documented
- ✅ Parallel execution is safe (MANUAL filtered out)
- ✅ Statistics are accurate
- ✅ Backward compatible

---

## 🎯 User Actions for MANUAL Items

1. **Review** - Read the check and reason
2. **Decide** - Does it apply to your cluster?
3. **Implement** - If applicable, do it manually
4. **Verify** - Re-run audit to confirm
5. **Document** - Keep record for audits

---

## 📊 Score Interpretation

### Automation Health = Pass/(Pass+Fail)
- **80-100%:** Scripts working well ✅
- **60-80%:** Some scripts need fixing ⚠️
- **<60%:** Multiple script issues 🔴
- **Note:** Higher = better script quality

### Audit Readiness = Pass/Total
- **80-100%:** Very compliant ✅
- **60-80%:** Mostly compliant ⚠️
- **<60%:** Significant gaps 🔴
- **Note:** Higher = better compliance state

---

## 🐛 Troubleshooting

| Issue | Check |
|-------|-------|
| MANUAL not showing | Run with `--verbose 2` |
| Scores seem wrong | Verify MANUAL excluded from calc |
| Item not marked MANUAL | Check 3 detection points |
| Parallel execution has MANUAL | Pre-filter should catch it |
| Stats not reset | Remediation start clears list |

---

## 📚 Documentation

| File | Purpose |
|------|---------|
| [MANUAL_CHECKS_REFACTORING_SUMMARY.md](MANUAL_CHECKS_REFACTORING_SUMMARY.md) | Implementation details |
| [MANUAL_CHECKS_FLOW_DIAGRAMS.md](MANUAL_CHECKS_FLOW_DIAGRAMS.md) | Visual guides |
| [MANUAL_CHECKS_INTEGRATION_GUIDE.md](MANUAL_CHECKS_INTEGRATION_GUIDE.md) | Developer reference |
| [DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md) | Full index |

---

## 🚀 Deployment

**Status:** ✅ Ready for production

**Changed:** `cis_k8s_unified.py` (~215 lines added/modified)  
**Backward Compatible:** Yes  
**Breaking Changes:** None  
**Testing:** Complete  

---

## 💭 Key Takeaway

**MANUAL checks are no longer problems - they're opportunities for human insight.**

Instead of blocking automation, they're clearly documented and handled separately so teams can:
- Focus automation on what can be automated
- Explicitly handle what needs human decisions
- Track both with equal clarity
- Report accurate metrics

---

*For detailed info, see [DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md)*
