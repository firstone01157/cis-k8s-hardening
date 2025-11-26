# Blue Team Quick Start Guide

## 3 New Features in 5 Minutes

### Feature 1: Mark Rules as Ignored (5 seconds)

Edit `cis_config.json`:
```json
{
    "excluded_rules": {
        "1.1.12": "RISK_ACCEPTED",
        "4.1.5": "IGNORED"
    }
}
```

Run audit. Those rules show as **IGNORED**, not **FAIL**.

✅ **Done** - Your compliance score now excludes risk-accepted items.

---

### Feature 2: See Results Grouped by Component (Automatic)

Run audit normally:
```bash
python3 cis_k8s_unified.py
```

In the results folder, you'll find a new file: **`component_summary.txt`**

Example output:
```
Etcd
- Pass: 8, Fail: 2

API Server
- Pass: 15, Fail: 3

Kubelet
- Pass: 25, Fail: 5
```

✅ **Done** - Focus remediation on worst-performing components.

---

### Feature 3: Track Score Changes Over Time (Automatic)

Run audit on Monday:
```
Score: 75.00%
```

Run audit on Tuesday:
```
Current Score:   78.50%
Previous Score:  75.00%
Change:          📈 +3.50%
```

✅ **Done** - See your progress automatically.

---

## Usage Examples

### Example 1: Accept a Risk Permanently
```json
"excluded_rules": {
    "1.2.15": "RISK_ACCEPTED - Legacy monitoring tool requires this"
}
```

### Example 2: Mark for Future Fixes
```json
"excluded_rules": {
    "4.1.2": "PLANNED_REMEDIATION - Scheduled for Feb 15"
}
```

### Example 3: Multiple Exclusions
```json
"excluded_rules": {
    "1.1.12": "RISK_ACCEPTED",
    "1.2.15": "RISK_ACCEPTED",
    "4.1.5": "PLANNED_REMEDIATION",
    "5.2.1": "ENVIRONMENT_CONSTRAINT"
}
```

---

## Files to Know

| File | Purpose |
|------|---------|
| `cis_config.json` | Add/remove excluded rules here |
| `results/YYYY-MM-DD/audit/run_*/component_summary.txt` | Component breakdown |
| `history/snapshot_*.json` | Trend data (auto-created) |

---

## Workflow in 3 Steps

### Step 1: Audit
```bash
python3 cis_k8s_unified.py
→ Select "1) Audit only"
```

### Step 2: Review
- Open `component_summary.txt` in latest results folder
- See which components are failing
- Add any risk-accepted items to `cis_config.json`

### Step 3: Track
- Next audit run will show `📈 Score: +X%`
- Compare components across dates
- Celebrate improvements!

---

## Common Tasks

### "We accept the risk on rule 1.1.12"
```json
"excluded_rules": {
    "1.1.12": "RISK_ACCEPTED - Approved by InfoSec board on Jan 15"
}
```

### "When did API Server issues get worse?"
```bash
cd results/
ls -la */audit/*/component_summary.txt
# Open each one, look for API Server section
```

### "Which component needs the most work?"
```bash
grep "Success Rate:" results/YYYY-MM-DD/audit/run_*/component_summary.txt | sort
```

### "Remove an exclusion"
```json
// Just delete the line from "excluded_rules"
"excluded_rules": {
    // "1.1.12": "RISK_ACCEPTED"   <-- Delete this when fixed
}
```

---

## What's Different Now

| Feature | Before | After |
|---------|--------|-------|
| Ignored Rules | Not supported | Show as IGNORED, don't count |
| Results View | Just pass/fail | Grouped by component |
| Trend Tracking | Manual spreadsheet | Automatic with emoji |

---

## Questions?

See **`REFACTORING_GUIDE.md`** for detailed documentation.

