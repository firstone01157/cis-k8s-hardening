# MANUAL CHECKS EXECUTION FLOW

## Remediation Execution Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│  START: run_remediation()                                           │
├─────────────────────────────────────────────────────────────────────┤
│  1. Load scripts from audit results                                 │
│  2. Call _run_remediation_with_split_strategy(scripts)             │
│  3. Reset: self.manual_pending_items = []                          │
└─────────────────────────┬───────────────────────────────────────────┘
                          │
        ┌─────────────────┴──────────────────┐
        │                                    │
        ▼                                    ▼
   ┌─────────────────────────────┐   ┌────────────────────────────────┐
   │ GROUP A (CRITICAL/CONFIG)   │   │  GROUP B (RESOURCES)           │
   │ Sequential Execution        │   │  Parallel Execution            │
   │ IDs: 1.*, 2.*, 3.*, 4.*     │   │  IDs: 5.*                     │
   └──────────┬──────────────────┘   └────────┬─────────────────────────┘
              │                                │
              │                                │
              │ For each script:               │ Pre-filter scripts:
              │                                │
              ▼                                ▼
    ┌─────────────────────────┐     ┌──────────────────────────┐
    │ Check if MANUAL?        │     │ Separate MANUAL vs      │
    │                         │     │ AUTOMATED checks         │
    │ 3-Point Detection:      │     └──────────┬───────────────┘
    │ 1. Config file          │                │
    │ 2. Audit results        │         ┌──────┴───────────────┐
    │ 3. Script content       │         │                      │
    └────┬────────────────────┘         ▼                      ▼
         │                     ┌──────────────────┐  ┌──────────────────┐
         │ If MANUAL: YES      │  MANUAL Items    │  │ AUTOMATED Items  │
         │ If MANUAL: NO       └────────┬─────────┘  └────────┬─────────┘
         │                              │                    │
         ▼                              ▼                    ▼
    ┌─────────────────┐        ┌──────────────────────┐ ┌──────────────────┐
    │ Skip execution  │        │ Add to               │ │ Execute in       │
    │ Add to          │        │ manual_pending_items │ │ parallel with    │
    │ manual_pending  │        │ Log: MANUAL_SKIP     │ │ ThreadPoolExec   │
    │ items           │        │ Continue (no stats)  │ │ Update stats     │
    │ Log event       │        └──────────────────────┘ │ as normal        │
    │ Continue        │                                 └──────────────────┘
    │ (no stats)      │
    └────────┬────────┘
             │
             │ After each GROUP A
             │ script:
             │
             ▼
    ┌──────────────────────────┐
    │ Health check             │
    │ If cluster unhealthy:    │
    │ STOP (catch issues early)│
    └──────────────────────────┘
```

## Decision Tree: Is This Check MANUAL?

```
                    ┌─────────────────────────┐
                    │ Check ID needed?        │
                    └────────┬────────────────┘
                             │
                    ┌────────┴────────┐
                    ▼                 ▼
              YES  ┌──────┐     NO  ┌──────┐
                   │      │         │      │
                   ▼      ▼         ▼      ▼
            
Step 1: CONFIG FILE CHECK
┌────────────────────────────────────────┐
│ Load remediation_config =              │
│ get_remediation_config_for_check(id)   │
├────────────────────────────────────────┤
│ if remediation == "manual":            │
│   ✓ YES, MANUAL                        │
│ else:                                  │
│   → Continue to Step 2                 │
└────────────────────────────────────────┘

Step 2: AUDIT RESULT CHECK
┌────────────────────────────────────────┐
│ if id in self.audit_results:           │
│   if status == "MANUAL":               │
│     ✓ YES, MANUAL                      │
│   else:                                │
│     → Continue to Step 3               │
│ else:                                  │
│   → Continue to Step 3                 │
└────────────────────────────────────────┘

Step 3: SCRIPT CONTENT CHECK
┌────────────────────────────────────────┐
│ if _is_manual_check(script_path):      │
│   ✓ YES, MANUAL                        │
│ else:                                  │
│   ✗ NO, AUTOMATED                      │
└────────────────────────────────────────┘
```

## Statistics Flow

```
BEFORE (Old Way):
┌──────────────────────────────────────────────────────────┐
│ 20 PASS + 5 FAIL + 10 MANUAL = 35 TOTAL                │
├──────────────────────────────────────────────────────────┤
│ Automation Health = 20 / 25 = 80%                        │
│ Audit Readiness = 20 / 35 = 57%                          │
│ Problem: MANUAL items lower both scores unfairly        │
└──────────────────────────────────────────────────────────┘

AFTER (New Way):
┌──────────────────────────────────────────────────────────┐
│ 20 PASS + 5 FAIL (+ 10 MANUAL tracked separately)       │
├──────────────────────────────────────────────────────────┤
│ Automation Health = 20 / (20+5) = 80%                   │
│   → Shows ONLY script effectiveness, not hindered by    │
│     items that can't be automated                       │
│                                                          │
│ Audit Readiness = 20 / (20+5) = 80%                     │
│   → Shows true compliance, MANUAL items displayed       │
│     separately as "pending human review"               │
│                                                          │
│ MANUAL Items (10 total):                               │
│   └─ Tracked in manual_pending_items[]                 │
│   └─ Displayed in separate report section               │
│   └─ User takes appropriate action                      │
└──────────────────────────────────────────────────────────┘
```

## Report Output Structure

```
================================================================================
COMPLIANCE STATUS: CLUSTER
================================================================================

1. AUTOMATION HEALTH (Technical Implementation)
   [Pass / (Pass + Fail)] - EXCLUDES Manual checks
   - Score: 87.50%
   - Status: Good
   - Meaning: How well remediation scripts are working

2. AUDIT READINESS (Overall CIS Compliance)
   [Pass / Total Checks] - INCLUDES all check types
   - Score: 82.35%
   - Status: Good
   - Meaning: True CIS compliance status

3. AUTOMATED FAILURES (❌ Need Script Fixes)
   ⚠ 5 automated checks FAILED
   Action: Debug and fix remediation scripts
   
================================================================================
DETAILED BREAKDOWN BY ROLE
================================================================================

  MASTER:
    Pass:       25
    Fail:       3
    Manual:     8  (Requires human review)
    Skipped:    2
    Total:      38
    Auto Health: 89.29% (of automated checks)
    Audit Ready: 75.68% (overall)

  WORKER:
    Pass:       18
    Fail:       2
    Manual:     5  (Requires human review)
    Skipped:    1
    Total:      26
    Auto Health: 90.00% (of automated checks)
    Audit Ready: 78.26% (overall)

================================================================================

📋 MANUAL INTERVENTION REQUIRED
Items skipped from automation for human review:

Total: 13 checks require manual review

MASTER NODE (8 items):
  • 1.2.1 [api-server]
    └─ Requires specific cluster architecture decision
  • 1.2.5 [api-server]
    └─ Depends on authentication system selection
  • 2.1.1 [etcd]
    └─ Requires backup strategy confirmation
  • 3.1.1 [rbac]
    └─ Needs role mapping to application service accounts
  • 4.1.1 [kubelet]
    └─ Kubelet config requires review before applying
  • 4.2.1 [kubelet]
    └─ May conflict with existing CRI configuration
  • 4.2.2 [kubelet]
    └─ Audit log path must match your infrastructure
  • 4.2.3 [kubelet]
    └─ Depends on logging infrastructure choice

WORKER NODE (5 items):
  • 4.1.2 [kubelet]
    └─ Worker-specific kubelet review required
  • 4.2.4 [kubelet]
    └─ Depends on centralized logging setup
  • 5.1.1 [networking]
    └─ NetworkPolicy namespace selection is environment-specific
  • 5.1.2 [networking]
    └─ Policy rules must match your application architecture
  • 5.1.3 [networking]
    └─ Egress rules need environment-specific configuration

Notes:
  • These checks are NOT failures or errors
  • They require human decisions that cannot be automated
  • They do NOT count against Automation Health score
  • They do NOT block remediation success

Recommended Actions:
  1. Review each manual item and understand what it requires
  2. Determine if the check applies to your cluster architecture
  3. If applicable, implement the fix manually following CIS guidelines
  4. Re-run audit to verify the fix
  5. Document any decisions for compliance audit trail

================================================================================
```

## Execution Timeline Example

```
Remediation Start: 2024-01-15 10:00:00

├─ Initialize
│  └─ Reset manual_pending_items = []
│  └─ Load 50 scripts to remediate
│
├─ GROUP A Execution (Sequential)
│  │
│  ├─ Script 1.1.1 [api-server]
│  │  ├─ MANUAL Detection: Config says "remediation": "manual" ✓
│  │  ├─ Action: SKIP (add to manual_pending_items)
│  │  └─ Log: MANUAL_CHECK_SKIPPED
│  │
│  ├─ Script 1.1.2 [api-server]
│  │  ├─ MANUAL Detection: NO
│  │  ├─ Action: EXECUTE
│  │  ├─ Result: PASS ✓
│  │  └─ Stats: pass += 1
│  │
│  ├─ Script 1.1.3 [api-server]
│  │  ├─ MANUAL Detection: Script content has MANUAL marker ✓
│  │  ├─ Action: SKIP (add to manual_pending_items)
│  │  └─ Log: MANUAL_CHECK_SKIPPED
│  │
│  ├─ Health Check: Cluster healthy ✓
│  └─ Continue to next...
│
├─ GROUP B Execution (Parallel)
│  │
│  ├─ Pre-filter: 15 scripts
│  │  ├─ MANUAL: 3 items → Skip, log, collect
│  │  └─ AUTOMATED: 12 items → Execute in parallel
│  │
│  ├─ Parallel Pool: Execute 12 automated scripts
│  │  ├─ Thread 1: Script 5.1.1 → PASS
│  │  ├─ Thread 2: Script 5.1.2 → PASS
│  │  ├─ Thread 3: Script 5.1.3 → FAIL (retry)
│  │  └─ ... (remaining threads)
│  │
│  └─ Wait for all threads to complete
│
├─ Generate Summary Report
│  ├─ Calculate Automation Health (excluding MANUAL)
│  ├─ Calculate Audit Readiness
│  ├─ Display automated failures (if any)
│  └─ Display manual_pending_items in dedicated section
│
└─ Remediation End: 2024-01-15 10:15:30
   ├─ Automated: 37 PASS, 5 FAIL ✓
   └─ Manual Pending: 8 items awaiting human review 🔍
```

## Key Differences: Before vs. After

```
BEFORE REFACTORING:
┌─────────────────────────────────────────────────────────┐
│ REMEDIATION RESULT: 37 PASS, 5 FAIL, 8 MANUAL          │
│                                                         │
│ Automation Health: 37 / (37+5+8) = 68% 😞             │
│ Audit Readiness: 37 / (37+5+8) = 68% 😞               │
│                                                         │
│ Problem: MANUAL items make scores look bad             │
│ Reality: Scripts are 88% effective, but it shows 68%   │
│ User Confusion: Why are manual checks counted against  │
│                 automation effectiveness?              │
└─────────────────────────────────────────────────────────┘

AFTER REFACTORING:
┌─────────────────────────────────────────────────────────┐
│ REMEDIATION RESULT: 37 PASS, 5 FAIL                    │
│ MANUAL PENDING: 8 items (tracked separately)           │
│                                                         │
│ Automation Health: 37 / (37+5) = 88% ✓                │
│ Audit Readiness: 37 / (37+5) = 88% ✓                  │
│                                                         │
│ MANUAL INTERVENTION REQUIRED:                          │
│   • 1.2.1 - Requires architecture decision             │
│   • 2.1.1 - Depends on backup strategy                 │
│   • 3.1.1 - Needs role mapping review                  │
│   ... (5 more items)                                   │
│                                                         │
│ Clarity: Scripts ARE 88% effective!                    │
│ Honesty: 8 items need human decisions (not failures)   │
│ Action: User knows exactly what to do next             │
└─────────────────────────────────────────────────────────┘
```

## Script Execution Safety

```
THREAD SAFETY: GROUP B Parallel Execution

PROBLEM: MANUAL checks if executed in parallel:
  - Multiple threads might try to access audit_results
  - Lock contention on logging
  - Race condition if manual check modifies cluster
  
SOLUTION: Filter BEFORE parallel execution
  
  ┌──────────────────────────────────┐
  │ Load all GROUP B scripts (15)     │
  └───────┬──────────────────────────┘
          │
          ▼
  ┌──────────────────────────────────┐
  │ For each script:                  │
  │  - Check MANUAL? YES → skip       │
  │  - Check MANUAL? NO → keep        │
  └───────┬──────────────────────────┘
          │
  ┌───────┴──────────────┐
  │                      │
  ▼                      ▼
  
MANUAL (3)         AUTOMATED (12)
  │                   │
  ├─ Log skip        ├─ Launch 4 threads
  ├─ Collect        ├─ Execute scripts
  └─ Continue       └─ Collect results
  
Result: Safe parallel execution, MANUAL items handled sequentially
```

---

**Complete visual documentation of MANUAL checks handling in CIS K8s Hardening.**
