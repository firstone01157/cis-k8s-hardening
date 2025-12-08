# CODE REFERENCE: Auto-Audit Implementation

## Summary

This document provides complete code reference for the auto-audit feature added to Option 3.

---

## File Modified

**File**: `cis_k8s_unified.py`  
**Method**: `main_loop()`  
**Lines**: ~1958-1983 (Option 3 handling)

---

## Complete Option 3 Code

### Location
Lines 1956-1984 in cis_k8s_unified.py

### Full Implementation

```python
elif choice == '3':  # Remediation FAILED ONLY / การแก้ไขเฉพาะรายการที่ล้มเหลว
    level, role, timeout = self.get_remediation_options()
    self.script_timeout = timeout
    
    # AUTO-AUDIT: If no audit results, run silent audit first
    if not self.audit_results:
        print(f"{Colors.CYAN}[INFO] No previous audit found. Running auto-audit to identify failures...{Colors.ENDC}")
        # Run audit silently with same level/role settings
        self.scan(level, role, skip_menu=True)
        print(f"\n{Colors.CYAN}[+] Auto-audit complete. Proceeding to remediation...{Colors.ENDC}")
    
    # Show summary of audit findings
    failed_count = sum(1 for r in self.audit_results.values() if r.get('status') in ['FAIL', 'ERROR', 'MANUAL'])
    passed_count = sum(1 for r in self.audit_results.values() if r.get('status') in ['PASS', 'FIXED'])
    
    print(f"\n{Colors.CYAN}{'='*70}")
    print("AUDIT SUMMARY")
    print(f"{'='*70}{Colors.ENDC}")
    print(f"  Total Audited:    {len(self.audit_results)}")
    print(f"  PASSED:           {Colors.GREEN}{passed_count}{Colors.ENDC}")
    print(f"  FAILED/MANUAL:    {Colors.RED}{failed_count}{Colors.ENDC}")
    print(f"{Colors.CYAN}{'='*70}{Colors.ENDC}\n")
    
    if failed_count == 0:
        print(f"{Colors.GREEN}[+] All checks passed! No remediation needed.{Colors.ENDC}")
        continue
    
    if self.confirm_action(f"Remediate {failed_count} failed/manual items?"):
        self.log_activity("FIX_FAILED_ONLY", f"Level:{level}, Role:{role}, Failed:{failed_count}")
        self.fix(level, role, fix_failed_only=True)
```

---

## Key Components

### 1. Condition Check

```python
if not self.audit_results:
```

**Purpose**: Detect if audit has been run  
**Type**: Dictionary empty check  
**Logic**: Only enters if `self.audit_results` is empty dict (falsy)

**Self.audit_results**:
- Type: Dictionary
- Keys: Check IDs (e.g., "1.1.1", "5.6.4")
- Values: Dict with 'status', 'role', 'level'
- Populated by: `_store_audit_results()` method
- Cleared on: New scan started

### 2. Auto-Audit Call

```python
self.scan(level, role, skip_menu=True)
```

**Method**: `scan(target_level, target_role, skip_menu=False)`  
**Parameters**:
- `level`: CIS level from user input ("1", "2", or "all")
- `role`: Node role from user input ("master", "worker", or "all")
- `skip_menu`: Boolean flag (True = skip results menu)

**Effect**:
- Runs full audit scan with parallel execution
- Stores results in `self.audit_results`
- Skips showing results menu (silent mode)
- Saves reports to disk
- Returns when complete

**Implementation in scan()**:
```python
def scan(self, target_level, target_role, skip_menu=False):
    # ... audit logic ...
    self._store_audit_results()  # Populates self.audit_results
    # ... more logic ...
    
    # Show results menu only if not skipped
    if not skip_menu:
        self.show_results_menu("audit")
    else:
        print(f"\n{Colors.CYAN}[*] Audit Complete. Proceeding to Remediation phase...{Colors.ENDC}")
```

### 3. Counting Failed Items

```python
failed_count = sum(1 for r in self.audit_results.values() 
                   if r.get('status') in ['FAIL', 'ERROR', 'MANUAL'])
passed_count = sum(1 for r in self.audit_results.values() 
                   if r.get('status') in ['PASS', 'FIXED'])
```

**Purpose**: Count failures and passes from audit results  
**Logic**:
- Iterate through all results values
- Count if status is in failed list: ['FAIL', 'ERROR', 'MANUAL']
- Count if status is in passed list: ['PASS', 'FIXED']

**Status Types**:
- `PASS`: Check passed compliance
- `FAIL`: Check failed compliance
- `ERROR`: Error during execution
- `MANUAL`: Requires manual review
- `FIXED`: Remediation was successful

### 4. Display Summary

```python
print(f"\n{Colors.CYAN}{'='*70}")
print("AUDIT SUMMARY")
print(f"{'='*70}{Colors.ENDC}")
print(f"  Total Audited:    {len(self.audit_results)}")
print(f"  PASSED:           {Colors.GREEN}{passed_count}{Colors.ENDC}")
print(f"  FAILED/MANUAL:    {Colors.RED}{failed_count}{Colors.ENDC}")
print(f"{Colors.CYAN}{'='*70}{Colors.ENDC}\n")
```

**Components**:
- `Colors.CYAN`: Cyan colored border
- `Colors.GREEN`: Green for passed count
- `Colors.RED`: Red for failed count
- `Colors.ENDC`: End color code
- Summary box: 70 chars wide

### 5. Check for All Passed

```python
if failed_count == 0:
    print(f"{Colors.GREEN}[+] All checks passed! No remediation needed.{Colors.ENDC}")
    continue
```

**Purpose**: Skip remediation if everything passed  
**Logic**:
- If `failed_count` is 0 (no failures)
- Display success message
- `continue` returns to main menu
- No remediation needed

### 6. Confirmation & Remediation

```python
if self.confirm_action(f"Remediate {failed_count} failed/manual items?"):
    self.log_activity("FIX_FAILED_ONLY", f"Level:{level}, Role:{role}, Failed:{failed_count}")
    self.fix(level, role, fix_failed_only=True)
```

**Methods**:
- `confirm_action(prompt)`: Shows [y/N] prompt, returns bool
- `log_activity(action, details)`: Log to activity log
- `fix(level, role, fix_failed_only)`: Execute remediation
  - `fix_failed_only=True`: Only fix failed checks

---

## Supporting Methods

### _store_audit_results()

**Location**: ~Line 1213  
**Purpose**: Store audit results in dictionary for later use

```python
def _store_audit_results(self):
    """Store current audit results in dictionary keyed by check ID"""
    self.audit_results.clear()
    
    for result in self.results:
        check_id = result.get('id')
        if check_id:
            self.audit_results[check_id] = {
                'status': result.get('status'),
                'role': result.get('role'),
                'level': result.get('level')
            }
```

**Called From**:
- `scan()` method after audit completes
- Automatically populates `self.audit_results`

### scan()

**Location**: ~Line 995  
**Purpose**: Execute audit scan

```python
def scan(self, target_level, target_role, skip_menu=False):
    """Execute audit scan with parallel execution"""
    # ... audit logic ...
    self._store_audit_results()  # Populate results
    # ... save reports, trend analysis ...
    
    # Skip menu if requested (used by auto-audit)
    if not skip_menu:
        self.show_results_menu("audit")
    else:
        print(f"\n{Colors.CYAN}[*] Audit Complete. Proceeding...{Colors.ENDC}")
```

### fix()

**Location**: ~Line 1100  
**Purpose**: Execute remediation

```python
def fix(self, target_level, target_role, fix_failed_only=False):
    """Execute remediation"""
    scripts = self.get_scripts("remediate", target_level, target_role)
    
    # Filter failed checks if fix_failed_only mode enabled
    if fix_failed_only:
        scripts = self._filter_failed_checks(scripts)
    
    # ... execute remediation ...
```

### _filter_failed_checks()

**Location**: ~Line 1167  
**Purpose**: Filter scripts to only failed items

```python
def _filter_failed_checks(self, scripts):
    """Filter scripts to only failed checks from audit"""
    failed_scripts = []
    
    for script in scripts:
        audit_status = self.audit_results.get(script['id'], {}).get('status')
        
        if audit_status in ['FAIL', 'ERROR']:
            failed_scripts.append(script)
        elif audit_status == 'MANUAL':
            failed_scripts.append(script)
    
    return failed_scripts
```

---

## Data Flow

### Initialization
```
CISUnifiedRunner.__init__()
    ↓
self.audit_results = {}  (empty dict)
```

### First Option 3 Selection (Auto-Audit)
```
main_loop() choice == '3'
    ↓
Get remediation options (level, role, timeout)
    ↓
Check: if not self.audit_results  (True - empty dict)
    ↓
self.scan(level, role, skip_menu=True)
    ↓
    Scan executes...
    ↓
    _store_audit_results() called
    ↓
    self.audit_results populated with check results
    ↓
Return from scan
    ↓
Count failed_count, passed_count
    ↓
Display summary
    ↓
Confirm & execute remediation
```

### Second Option 3 Selection (No Auto-Audit)
```
main_loop() choice == '3'
    ↓
Get remediation options (level, role, timeout)
    ↓
Check: if not self.audit_results  (False - has data from previous run)
    ↓
Skip auto-audit (no scan call)
    ↓
Count failed_count, passed_count (from cached results)
    ↓
Display summary
    ↓
Confirm & execute remediation
```

---

## Message Text

### Auto-Audit Started
```python
f"{Colors.CYAN}[INFO] No previous audit found. Running auto-audit to identify failures...{Colors.ENDC}"
```

### Auto-Audit Complete
```python
f"\n{Colors.CYAN}[+] Auto-audit complete. Proceeding to remediation...{Colors.ENDC}"
```

### All Passed
```python
f"{Colors.GREEN}[+] All checks passed! No remediation needed.{Colors.ENDC}"
```

### Confirmation Prompt
```python
f"Remediate {failed_count} failed/manual items?"
```

---

## Integration Points

### With Smart Wait
```python
# In _run_remediation_with_split_strategy()
requires_health_check, classification = self._classify_remediation_type(script['id'])

# Auto-audit results used to determine health checks
# Safe checks (1.1.x) skip health check
# Critical checks get full health check
```

### With Smart Override
```python
# In _parse_script_output()
if is_manual:
    if "[PASS]" in combined_output:
        status = "PASS"  # Override MANUAL to PASS

# Auto-audit respects smart override decisions
# MANUAL checks with [PASS] output counted as PASS
```

### With Failed-Only Remediation
```python
# In fix()
if fix_failed_only:
    scripts = self._filter_failed_checks(scripts)

# Auto-audit populates audit_results
# _filter_failed_checks() uses those results
# Only failed checks are remediated
```

---

## Error Handling

### No audit results even after scan
```python
if not self.audit_results:
    # This shouldn't happen if scan() completed
    # But could happen if scan was interrupted
    # Would trigger another auto-audit attempt
```

### Empty failed_count
```python
if failed_count == 0:
    # No failures found
    # Skip remediation
    # Return to menu
```

### User cancels remediation
```python
if self.confirm_action(...):
    # Only executes if user confirms (y/Y)
    # If user confirms "n" or presses enter
    # Continues main loop (returns to menu)
```

---

## Code Changes Summary

| Aspect | Details |
|--------|---------|
| **Files Modified** | 1 (cis_k8s_unified.py) |
| **Lines Changed** | ~15 (Option 3 logic) |
| **Methods Modified** | 1 (main_loop) |
| **Methods Added** | 0 (reused existing methods) |
| **Breaking Changes** | None |
| **Backward Compatible** | 100% |

---

## Testing Code Examples

### Unit Test: Check auto-audit condition
```python
# Test 1: Empty audit_results should trigger auto-audit
runner = CISUnifiedRunner()
assert runner.audit_results == {}
# Auto-audit should run

# Test 2: Populated audit_results should skip auto-audit
runner = CISUnifiedRunner()
runner.audit_results = {'1.1.1': {'status': 'PASS'}}
# Auto-audit should NOT run
```

### Integration Test: Full workflow
```python
# Test 1: Option 3 on fresh start
# Select Option 3 → Auto-audit runs → Summary shown → Remediation

# Test 2: Option 3 after Option 1
# Select Option 1 (Audit) → Select Option 3 → No auto-audit → Remediation

# Test 3: All checks pass
# Option 3 → Auto-audit → All passed → Back to menu

# Test 4: User cancels
# Option 3 → Auto-audit → Prompt → User says "n" → Back to menu
```

---

## Related Code Sections

**Auto-audit trigger**:
```python
if not self.audit_results:
    self.scan(level, role, skip_menu=True)
```

**Result storage**:
```python
self._store_audit_results()
```

**Result filtering**:
```python
self._filter_failed_checks(scripts)
```

**Remediation execution**:
```python
self.fix(level, role, fix_failed_only=True)
```

---

## Summary

The auto-audit feature is a clean, minimal addition that:
1. Checks for empty audit results
2. Runs silent audit if needed
3. Displays summary
4. Proceeds to remediation

No existing code was removed, only the menu option 3 logic was enhanced to handle the no-audit case automatically.

---

**Documentation Version**: 1.0  
**Date**: December 8, 2025  
**Status**: Complete
