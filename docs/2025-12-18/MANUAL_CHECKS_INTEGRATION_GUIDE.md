# MANUAL CHECKS INTEGRATION GUIDE

## Developer Reference: How MANUAL Checks Work

This guide explains how MANUAL checks integrate into the CIS K8s Hardening system and how to work with them.

---

## 1. Architecture Overview

### Core Components

```
cis_k8s_unified.py
├── CISUnifiedRunner (main class)
│   ├── __init__() 
│   │   └─ self.manual_pending_items = [] ← NEW: Tracks MANUAL items
│   │
│   ├── run_remediation()
│   │   └─ Calls _run_remediation_with_split_strategy()
│   │
│   ├── _run_remediation_with_split_strategy()
│   │   ├─ GROUP A (Sequential)
│   │   │   └─ 3-point MANUAL detection + skip logic
│   │   │
│   │   └─ GROUP B (Parallel)
│   │       └─ Pre-filter MANUAL before ThreadPoolExec
│   │
│   ├── get_remediation_config_for_check()
│   │   └─ Detection Point 1: Config says "remediation": "manual"?
│   │
│   ├── _is_manual_check()
│   │   └─ Detection Point 3: Script has MANUAL marker?
│   │
│   ├── calculate_compliance_scores()
│   │   └─ Updated: Exclude MANUAL from Automation Health
│   │
│   └── print_stats_summary()
│       └─ NEW: Dedicated "📋 MANUAL INTERVENTION REQUIRED" section
│
└── Configuration & Data
    ├── cis_config.json
    │   └─ Per-check: "remediation": "manual" | "auto"
    │
    ├── audit_results[]
    │   └─ Detection Point 2: status == "MANUAL"?
    │
    └── manual_pending_items[]
        └─ Collected MANUAL items with metadata
```

---

## 2. Data Flow: How a MANUAL Check is Detected and Handled

### Step-by-Step Trace

```
1. LOAD PHASE
   └─ run_remediation() loads scripts from audit_results

2. INITIALIZE REMEDIATION
   ├─ Call _run_remediation_with_split_strategy(scripts)
   └─ Reset: self.manual_pending_items = []

3. FOR EACH SCRIPT IN GROUP A:
   
   a) DETECTION:
      ├─ Read script['id'] (e.g., "1.2.1")
      │
      ├─ Detection Point 1: CONFIG
      │  └─ remediation_cfg = get_remediation_config_for_check("1.2.1")
      │     if remediation_cfg.get("remediation") == "manual":
      │        is_manual = True → STOP, GOTO b)
      │
      ├─ Detection Point 2: AUDIT RESULTS
      │  └─ if "1.2.1" in self.audit_results:
      │        status = self.audit_results["1.2.1"].get('status')
      │        if status == 'MANUAL':
      │           is_manual = True → STOP, GOTO b)
      │
      └─ Detection Point 3: SCRIPT CONTENT
         └─ if _is_manual_check(script['path']):
              is_manual = True → STOP, GOTO b)
   
   b) DECISION:
      ├─ if is_manual == True:
      │  │
      │  ├─ Append to self.manual_pending_items:
      │  │  {
      │  │    'id': script['id'],
      │  │    'role': script.get('role'),
      │  │    'level': script.get('level'),
      │  │    'path': script['path'],
      │  │    'reason': 'Reason for MANUAL classification',
      │  │    'component': script.get('component')
      │  │  }
      │  │
      │  ├─ Log activity: MANUAL_CHECK_SKIPPED
      │  │
      │  └─ continue  ← SKIP execution, go to next script
      │
      └─ else (not manual):
         ├─ Execute script (run remediation)
         ├─ Check result (PASS/FAIL)
         ├─ Update stats: stats[role][status] += 1
         ├─ Run health check (if configured)
         └─ Continue to next script

4. FOR EACH SCRIPT IN GROUP B:
   
   a) PRE-FILTER (before ThreadPoolExec):
      ├─ Create group_b_automated = []
      ├─ Create group_b_manual = []
      │
      └─ For each script in group_b:
         ├─ (Same 3-point detection as GROUP A)
         │
         ├─ if is_manual:
         │  └─ Append (script, reason) to group_b_manual
         │
         └─ else:
            └─ Append script to group_b_automated
   
   b) HANDLE MANUAL:
      └─ For each (script, reason) in group_b_manual:
         ├─ Append to manual_pending_items
         ├─ Log: MANUAL_CHECK_SKIPPED
         └─ (Don't execute in parallel)
   
   c) EXECUTE AUTOMATED:
      └─ ThreadPoolExecutor.map():
         └─ Execute only group_b_automated scripts

5. SUMMARY PHASE
   └─ print_stats_summary():
      ├─ Calculate Automation Health = Pass / (Pass + Fail)
      │                                [EXCLUDES MANUAL]
      │
      ├─ Calculate Audit Readiness = Pass / (Pass + Fail)
      │                             [EXCLUDES MANUAL]
      │
      ├─ Show automated failures (script issues)
      │
      └─ Show "📋 MANUAL INTERVENTION REQUIRED" section:
         └─ List all items in manual_pending_items[]
         └─ Group by role for clarity
         └─ Show action items for user
```

---

## 3. Detection Logic: How MANUAL is Identified

### Configuration-Based Detection

**File:** `cis_config.json`

```json
{
  "checks": {
    "1.2.1": {
      "title": "Ensure API server service parameters are set",
      "remediation": "manual"  ← KEY: This marks it as MANUAL
    },
    "1.2.2": {
      "title": "Ensure API server endpoint encryption",
      "remediation": "auto"     ← This is automated
    }
  }
}
```

**Code:**
```python
remediation_cfg = self.get_remediation_config_for_check(check_id)
if remediation_cfg.get("remediation") == "manual":
    is_manual = True
```

**Priority:** Checked FIRST - highest priority

---

### Audit Results-Based Detection

**Data Structure:** `self.audit_results` dict

```python
self.audit_results = {
    "1.2.1": {
        'id': '1.2.1',
        'status': 'MANUAL',  ← KEY: Status is MANUAL
        'reason': 'Requires human decision on API server config',
        ...
    },
    "1.2.2": {
        'id': '1.2.2',
        'status': 'PASS',    ← Already compliant
        ...
    }
}
```

**Code:**
```python
if script['id'] in self.audit_results:
    status = self.audit_results[script['id']].get('status')
    if status == 'MANUAL':
        is_manual = True
```

**Priority:** Checked SECOND - middle priority

---

### Script Content-Based Detection

**File:** Individual remediation script (e.g., `1.1.1_remediate.sh`)

**Marker:** Script file contains word "MANUAL" or `# MANUAL` comment

```bash
#!/bin/bash
# Script: 1.1.1 - Ensure etcd is backed up
# MANUAL: This check requires backup configuration specific to your environment
# Action: Review backup strategy before running

# ... script code ...
```

**Code:**
```python
def _is_manual_check(self, script_path):
    """Check if script file contains MANUAL marker."""
    try:
        with open(script_path, 'r') as f:
            content = f.read()
            return 'MANUAL' in content  # Simple string search
    except:
        return False

if _is_manual_check(script['path']):
    is_manual = True
```

**Priority:** Checked LAST - lowest priority (fallback)

---

## 4. Statistics & Scoring

### Stats Dictionary Structure

```python
self.stats = {
    'master': {
        'pass': 20,      # Passed automated checks
        'fail': 3,       # Failed automated checks
        'manual': 8,     # MANUAL checks (not executed)
        'skipped': 2,    # Skipped (not required)
        'error': 1,      # Execution errors
        'total': 34      # Total checks for master
    },
    'worker': {
        'pass': 15,
        'fail': 2,
        'manual': 5,
        'skipped': 1,
        'error': 0,
        'total': 23
    }
}
```

### Score Calculations

#### Automation Health (Script Effectiveness)
```python
def calculate_automation_health(stats):
    """
    Shows how well remediation scripts work.
    EXCLUDES manual checks (items that can't be automated).
    """
    total_pass = stats['master']['pass'] + stats['worker']['pass']
    total_fail = stats['master']['fail'] + stats['worker']['fail']
    
    if total_pass + total_fail == 0:
        return 0.0
    
    automation_health = (total_pass / (total_pass + total_fail)) * 100
    return automation_health

# Example:
# 35 PASS, 5 FAIL, 8 MANUAL
# Automation Health = 35 / (35 + 5) = 87.5%
# NOT: 35 / (35 + 5 + 8) = 66%
```

#### Audit Readiness (Compliance Status)
```python
def calculate_audit_readiness(stats):
    """
    Shows true CIS compliance.
    INCLUDES all types but calculates from non-manual total.
    """
    total_pass = stats['master']['pass'] + stats['worker']['pass']
    # Total = Pass + Fail + Skipped + Error (NOT Manual)
    total_for_audit = (total_pass + 
                       stats['master']['fail'] + stats['worker']['fail'] +
                       stats['master']['skipped'] + stats['worker']['skipped'] +
                       stats['master']['error'] + stats['worker']['error'])
    
    if total_for_audit == 0:
        return 0.0
    
    audit_readiness = (total_pass / total_for_audit) * 100
    return audit_readiness

# Example:
# 35 PASS, 5 FAIL, 3 SKIPPED, 8 MANUAL
# Total = 35 + 5 + 3 = 43 (not including MANUAL)
# Audit Ready = 35 / 43 = 81.4%
```

---

## 5. Integration Points: Where MANUAL Checks Fit

### In the Remediation Loop

```python
def _run_remediation_with_split_strategy(self, scripts):
    # ... GROUP A PROCESSING ...
    for script in group_a:
        # ★ MANUAL DETECTION & SKIP HAPPENS HERE ★
        if self._detect_manual_check(script):
            self.manual_pending_items.append(...)
            continue
        
        # Execute only if NOT manual
        result = self._execute_script(script)
        self._update_stats(result)
    
    # ... GROUP B PROCESSING ...
    # ★ PRE-FILTER BEFORE PARALLEL ★
    automated, manual = self._filter_manual_checks(group_b)
    
    # Handle manual
    for script, reason in manual:
        self.manual_pending_items.append(...)
    
    # Execute only automated in parallel
    with ThreadPoolExecutor() as executor:
        executor.map(self._execute_script, automated)
```

### In the Reporting

```python
def print_stats_summary(self):
    # ... Show scores ...
    print(f"Automation Health: {scores['automation_health']:.2f}%")
    print(f"Audit Readiness: {scores['audit_readiness']:.2f}%")
    
    # ... Show failures ...
    print("Automated Failures: ...")
    
    # ★ NEW: Show MANUAL items separately ★
    print("\n📋 MANUAL INTERVENTION REQUIRED")
    for item in self.manual_pending_items:
        print(f"  • {item['id']}: {item['reason']}")
```

### In the Configuration

```python
# cis_config.json
{
  "checks": {
    "1.2.1": {
      "remediation": "manual"  ← Marks as MANUAL
    }
  },
  "remediation": {
    "strategy": "split",           ← Use GROUP A/B split
    "group_a_health_check": true   ← Health check after each GROUP A
  }
}
```

---

## 6. How to Add a MANUAL Check

### Option 1: Via Configuration

**File:** `cis_config.json`

```json
{
  "checks": {
    "1.2.1": {
      "title": "Your Check Title",
      "remediation": "manual"  ← Add this line
    }
  }
}
```

**Effect:** Check will be detected as MANUAL, skipped, and tracked separately.

---

### Option 2: Via Script Marker

**File:** `Level_1_Master_Node/1.2.1_remediate.sh`

```bash
#!/bin/bash
# MANUAL: This check requires reviewing API server audit logs
# which are environment-specific and may contain sensitive data.

# Your remediation code here...
```

**Effect:** Script containing "MANUAL" will be detected and skipped.

---

### Option 3: Via Audit Status

**Location:** `self.audit_results` after audit run

```python
# In audit phase:
self.audit_results["1.2.1"] = {
    'status': 'MANUAL',  ← Set status to MANUAL
    'reason': 'Requires human decision'
}
```

**Effect:** Check marked MANUAL in previous audit stays MANUAL in remediation.

---

## 7. Debugging & Troubleshooting

### Enable Verbose Output

```bash
python cis_k8s_unified.py remediate --verbose 2
```

**Output will show:**
- Detection decisions for each check
- Which detection point triggered (config/audit/script)
- Reason for MANUAL classification
- Skip actions

### Check Manual Pending Items

```python
# In Python code:
runner = CISUnifiedRunner(config, verbose=2)
runner.run_remediation()

# Access collected items:
print(f"Manual items: {len(runner.manual_pending_items)}")
for item in runner.manual_pending_items:
    print(f"  {item['id']}: {item['reason']}")
```

### View Detection Logic

Search in `cis_k8s_unified.py` for:
- `get_remediation_config_for_check()` - Config detection
- `_is_manual_check()` - Script content detection
- `_detect_manual_check()` - Combined detection function

### Verify Statistics

```python
# Check stats before MANUAL separation:
print(runner.stats['master'])
# Output: {'pass': 35, 'fail': 5, 'manual': 8, ...}

# Calculate scores (excludes MANUAL):
scores = runner.calculate_compliance_scores(runner.stats)
print(f"Automation Health: {scores['automation_health']:.2f}%")
```

---

## 8. Common Scenarios

### Scenario 1: Check Marked MANUAL in Config

```json
{
  "1.2.1": {
    "remediation": "manual"
  }
}
```

**What happens:**
1. Script 1.2.1 is loaded for remediation
2. Detection Point 1 (config) returns True
3. Script is added to `manual_pending_items`
4. Script is NOT executed
5. Stats are NOT updated with this check
6. Summary shows it in "MANUAL INTERVENTION" section

---

### Scenario 2: Check Already MANUAL from Audit

```python
audit_results = {
    "1.2.1": {
        "status": "MANUAL",
        "reason": "..."
    }
}
```

**What happens:**
1. Script 1.2.1 is loaded for remediation
2. Detection Point 1 (config) returns False
3. Detection Point 2 (audit) returns True
4. Script is added to `manual_pending_items`
5. Script is NOT executed
6. Summary shows status unchanged from audit

---

### Scenario 3: MANUAL in Script Content

```bash
# 4.1.1_remediate.sh contains:
# MANUAL: Kubelet requires cluster-specific configuration
```

**What happens:**
1. Script 4.1.1 is loaded for remediation
2. Detection Point 1 (config) returns False
3. Detection Point 2 (audit) returns False
4. Detection Point 3 (script) returns True
5. Script is added to `manual_pending_items`
6. Script is NOT executed
7. Summary shows it with extracted reason

---

## 9. Backward Compatibility

### Old Code Still Works

```python
# Old: Checking if any result is MANUAL
if any(r['status'] == 'MANUAL' for r in results):
    # ... handle MANUAL ...
```

**Still works because:**
- `results` list still includes MANUAL items (with status='MANUAL')
- `manual_pending_items` is additional, not replacement
- Statistics still track MANUAL count

### Migration Path

**Before:** Results include MANUAL, counts affect scores
```python
results = [
    {'id': '1.2.1', 'status': 'MANUAL'},
    {'id': '1.2.2', 'status': 'PASS'},
    {'id': '1.2.3', 'status': 'FAIL'}
]

# Old score calculation:
score = 1 / (1 + 1 + 1) = 33.3%  ✗ Incorrect
```

**After:** MANUAL items separated, scores accurate
```python
results = [
    {'id': '1.2.2', 'status': 'PASS'},
    {'id': '1.2.3', 'status': 'FAIL'}
]
manual_pending_items = [
    {'id': '1.2.1', ...}
]

# New score calculation:
score = 1 / (1 + 1) = 50%  ✓ Correct
# MANUAL tracked separately in summary
```

---

## 10. Best Practices

### ✅ DO

- ✅ Mark checks as MANUAL in config if they need human input
- ✅ Add MANUAL marker comment in script explaining why
- ✅ Review `manual_pending_items` after remediation
- ✅ Follow the action items in the summary report
- ✅ Document why each check is manual for audit trail
- ✅ Re-run audit after implementing manual fixes

### ❌ DON'T

- ❌ Mix MANUAL and FAIL - separate them clearly
- ❌ Skip remediation entirely for MANUAL checks
- ❌ Execute MANUAL checks in automated pipelines without review
- ❌ Ignore the "MANUAL INTERVENTION REQUIRED" section
- ❌ Assume MANUAL checks don't affect compliance
- ❌ Change MANUAL status without documenting reason

---

## 11. Testing MANUAL Check Handling

### Test 1: Verify Detection

```bash
# Run with verbose output
python cis_k8s_unified.py remediate --verbose 2

# Should show:
# ✓ MANUAL_CHECK_SKIPPED for each manual item
# ✓ Reason for manual classification
# ✓ Which detection point triggered
```

### Test 2: Verify Statistics

```bash
# After remediation, check stats:
# Automation Health should be: Pass / (Pass + Fail)
# Should NOT include MANUAL in denominator

# Audit Readiness should be: Pass / (Pass + Fail)
# Should exclude MANUAL from total
```

### Test 3: Verify Summary Report

```bash
# Look for new section:
# 📋 MANUAL INTERVENTION REQUIRED
# Should list all manual items
# Should provide action items
```

### Test 4: Verify Parallel Safety

```bash
# GROUP B should not execute MANUAL checks
# Check logs for only automated GROUP B items running
# MANUAL items should be logged as SKIPPED
```

### Test 5: Verify Reset on New Run

```bash
# First run: Some MANUAL items
# Second run: manual_pending_items should be reset
# Counts should not carryover from previous run
```

---

**Integration guide complete. Ready for development and maintenance.**
