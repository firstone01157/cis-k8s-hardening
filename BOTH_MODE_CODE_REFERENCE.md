# Both Mode UX Improvement - Code Reference

## Updated scan() Method

```python
def scan(self, target_level, target_role, skip_menu=False):
    """
    Execute audit scan with parallel execution
    ดำเนินการสแกนการตรวจสอบพร้อมการดำเนินการแบบขนาน
    
    Args:
        target_level: CIS level to audit ("1", "2", or "all")
        target_role: Target node role ("master", "worker", or "all")
        skip_menu: If True, skip results menu (used when in "Both" mode)
    """
    print(f"\n{Colors.CYAN}[*] Starting Audit Scan...{Colors.ENDC}")
    self.log_activity("AUDIT_START", 
                     f"Level:{target_level}, Role:{target_role}, Timeout:{self.script_timeout}s")
    
    self._prepare_report_dir("audit")
    scripts = self.get_scripts("audit", target_level, target_role)
    self.results = []
    self._init_stats()
    
    # Execute scripts in parallel / ดำเนินการสคริปต์แบบขนาน
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        self._run_scripts_parallel(executor, scripts, "audit")
    
    print(f"\n{Colors.GREEN}[+] Audit Complete.{Colors.ENDC}")
    self.save_reports("audit")
    self.print_stats_summary()
    
    # Trend analysis / การวิเคราะห์แนวโน้ม
    current_score = self.calculate_score(self.stats)
    previous = self.get_previous_snapshot("audit", target_role, target_level)
    if previous:
        self.show_trend_analysis(current_score, previous)
    
    self.save_snapshot("audit", target_role, target_level)
    
    # Show results menu only if not skipped (e.g., in "Both" mode)
    if not skip_menu:
        self.show_results_menu("audit")
    else:
        print(f"\n{Colors.CYAN}[*] Audit Complete. Proceeding to Remediation phase...{Colors.ENDC}")
```

---

## Updated main_loop() Method - Mode 3 Section

```python
elif choice == '3':  # Both / ทั้งสอง
    level, role, verbose, skip_manual, timeout = self.get_audit_options()
    self.verbose = verbose
    self.script_timeout = timeout
    self.log_activity("AUDIT_THEN_FIX", f"Level:{level}, Role:{role}")
    self.scan(level, role, skip_menu=True)
    
    if self.confirm_action("Proceed to remediation?"):
        self.fix(level, role)
```

---

## Key Changes

### 1. Parameter Addition
```python
# Before:
def scan(self, target_level, target_role):

# After:
def scan(self, target_level, target_role, skip_menu=False):
```

### 2. Conditional Menu Display
```python
# Before:
self.save_snapshot("audit", target_role, target_level)
self.show_results_menu("audit")

# After:
self.save_snapshot("audit", target_role, target_level)

if not skip_menu:
    self.show_results_menu("audit")
else:
    print(f"\n{Colors.CYAN}[*] Audit Complete. Proceeding to Remediation phase...{Colors.ENDC}")
```

### 3. Mode 3 Call Update
```python
# Before:
self.scan(level, role)

# After:
self.scan(level, role, skip_menu=True)
```

---

## Behavior Matrix

| Mode | Call | skip_menu | Result |
|------|------|-----------|--------|
| 1 (Audit) | `scan(level, role)` | False (default) | Results menu shown ✓ |
| 3 (Both) | `scan(level, role, skip_menu=True)` | True | Transition msg, no menu ✓ |

---

## Output Comparison

### Mode 1: Audit (Results Menu Shown)
```
[+] Audit Complete.
[STATS] ...
[TREND] ...
═══════════════════════════════════════════════════════
RESULTS MENU
═══════════════════════════════════════════════════════
1) View summary
2) View failed items
3) View HTML report
4) Return to main menu
```

### Mode 3: Both (Transition Message Shown)
```
[+] Audit Complete.
[STATS] ...
[TREND] ...
[*] Audit Complete. Proceeding to Remediation phase...

Proceed to remediation? [y/n]:
```

---

## Verification

```bash
# Syntax check
python3 -m py_compile cis_k8s_unified.py

# Run in Mode 3
sudo python3 cis_k8s_unified.py
# Select: 3
# Verify: No results menu appears between audit and remediation
# Verify: Transition message shown
# Verify: Remediation proceeds immediately after confirmation
```

---

**Status**: ✅ PRODUCTION READY
