# Smart Wait - Visual Architecture & Flow Diagram

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    CIS Kubernetes Hardener                              │
│                   with Smart Wait Optimization                          │
└─────────────────────────────────────────────────────────────────────────┘

                              Main Entry
                                  │
                                  ▼
                         ┌──────────────────┐
                         │  remediate()     │
                         └────────┬─────────┘
                                  │
                                  ▼
            ┌─────────────────────────────────────────────┐
            │ _run_remediation_with_split_strategy()      │
            │      (Smart Wait enabled version)           │
            └────────────────┬────────────────────────────┘
                             │
            ┌────────────────┴────────────────┐
            │                                 │
            ▼                                 ▼
    ┌──────────────────┐           ┌──────────────────┐
    │   GROUP A        │           │   GROUP B        │
    │   Sequential     │           │   Parallel       │
    │ (Smart Wait)     │           │  (Unchanged)     │
    └────────┬─────────┘           └──────┬───────────┘
             │                            │
             ▼                            ▼
    Process each check          Process multiple
    with classification          checks in parallel
             │                            │
             └────────────────┬───────────┘
                              │
                              ▼
                         Complete
```

---

## Group A Execution Flow (Smart Wait)

```
GROUP A EXECUTION (Smart Wait Enabled)
════════════════════════════════════════════════════════════════════════════

┌─ START: Load 30 Group A checks (20 safe, 10 config) ─────────────────────┐
│                                                                             │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                    ╔══════════════════╩════════════════════╗
                    │  for each check in group_a:          │
                    ╚══════════════════╤════════════════════╝
                                       │
                                       ▼
              ┌────────────────────────────────────────────┐
              │ Check 1-20: 1.1.1, 1.1.2, ..., 1.1.20     │
              │ (Safe: File Permissions)                   │
              └────────┬───────────────────────────────────┘
                       │
    ┌──────────────────┴──────────────────┐
    │                                     │
    ▼                                     ▼
EXECUTE SCRIPT                    CLASSIFY TYPE
    │                                     │
    ├─ run: chmod ...                     └─ Pattern: 1.1.
    └─ Status: FIXED                      └─ Result: SAFE
                                          └─ Health Check: [SKIP]
                                             
    ┌──────────────────────────────────────────────────────┐
    │ SKIP HEALTH CHECK (Save ~25 seconds per check)       │
    │ Continue immediately to next check                   │
    │                                                      │
    │ ✓ Track: skipped_health_checks.append('1.1.X')      │
    │ ✓ Print: [OK] Safe operation (no health check needed)│
    └────────────────────┬─────────────────────────────────┘
                         │
                         ▼
                    [NEXT CHECK]
                         │
                         ▼
              ┌────────────────────────────────────────────┐
              │ Check 21-30: 1.2.1, 1.2.2, 2.1, 3.1, ...  │
              │ (Config/Service: API, etcd, Control Plane) │
              └────────┬───────────────────────────────────┘
                       │
    ┌──────────────────┴──────────────────┐
    │                                     │
    ▼                                     ▼
EXECUTE SCRIPT                    CLASSIFY TYPE
    │                                     │
    ├─ run: sed -i "..." ...              └─ Pattern: 1.2., 2., 3.
    └─ Status: FIXED                      └─ Result: CONFIG
                                          └─ Health Check: [REQUIRED]
                                             
    ┌──────────────────────────────────────────────────────┐
    │ PERFORM HEALTH CHECK (25 seconds)                    │
    │   1. Check TCP port 6443                             │
    │   2. Check /readyz endpoint                          │
    │   3. Wait settle time (15 seconds)                   │
    │                                                      │
    │ ✓ If healthy → Continue                             │
    │ ✗ If unhealthy → EMERGENCY BRAKE (exit)             │
    │ ✓ Track: performed_health_checks.append('1.2.X')    │
    └────────────────────┬─────────────────────────────────┘
                         │
                         ▼
                    [NEXT CHECK]
                         │
                         ▼
            ┌────────────────────────────────┐
            │ ALL CHECKS COMPLETED           │
            │ (20 safe + 10 config)          │
            └────────┬───────────────────────┘
                     │
                     ▼
    ┌─────────────────────────────────────────────┐
    │ FINAL STABILITY CHECK                       │
    │ (Only if any safe checks were performed)    │
    │                                             │
    │ Validates cumulative effect of all safe ops │
    │ Full health check: TCP + readyz + settle    │
    │                                             │
    │ ✓ If healthy → Proceed to GROUP B           │
    │ ✗ If unhealthy → EMERGENCY BRAKE (exit)     │
    └────────┬────────────────────────────────────┘
             │
             ▼
    ┌─────────────────────────────────────────────┐
    │ PRINT SUMMARY                               │
    │                                             │
    │ [GROUP A SUMMARY]                          │
    │   Health checks skipped: 20                 │
    │   Health checks performed: 10               │
    │   Final stability check: PASSED             │
    │                                             │
    │ Time taken: ~6-7 minutes                    │
    │ (vs original ~12-14 minutes)                │
    └────────┬────────────────────────────────────┘
             │
             ▼
    GROUP A COMPLETE → PROCEED TO GROUP B
```

---

## Time Comparison: Original vs Smart Wait

```
ORIGINAL EXECUTION (No Smart Wait)
═══════════════════════════════════════════════════════════════════════════

Time: 0        5        10       15       20       25       30
      ├────────┼────────┼────────┼────────┼────────┼────────┤

Check 1.1.1 [RUN]         Check 1.1.1 [HEALTH CHECK] ─────────────┐
Check 1.1.2                [RUN]         Check 1.1.2 [HEALTH CHECK] ─┐
Check 1.1.3                               [RUN]         [HEALTH CHECK]─┐
... (repeated for 20 safe checks) ...                                 │
                                                                       │
Result: 30 checks × 25 seconds = 750 seconds (12.5 minutes)           │


SMART WAIT EXECUTION (Optimized)
═══════════════════════════════════════════════════════════════════════════

Time: 0        5        10       15       20       25       30
      ├────────┼────────┼────────┼────────┼────────┼────────┤

Check 1.1.1 [RUN] Check 1.1.2 [RUN] Check 1.1.3 [RUN] ... (fast) ────┐
                                                                      │
Check 1.2.1 [RUN]     Check 1.2.1 [HEALTH CHECK] ────────────┐       │
Check 1.2.2             [RUN]     Check 1.2.2 [HEALTH CHECK] ├────┐  │
... (repeated for config checks) ...                          │    │  │
                                                              │    │  │
                                                     FINAL CHECK ──┘  │
                                                              │       │
Result: (20×5s) + (10×25s) + 25s = 375 seconds (6.25 minutes)       │


SAVINGS: 375 seconds (50% faster!) ◄─────────────────────────────────┘
```

---

## Classification Decision Tree

```
                    ┌─ Is this remediation check? ─┐
                    │                               │
                    ▼                               │
            ┌──────────────────┐                    │
            │ START CHECK      │                    │
            └────────┬─────────┘                    │
                     │                              │
                     ▼                              │
    ┌────────────────────────────────┐              │
    │ Check ID = ?                   │              │
    │ (e.g., '1.1.1', '1.2.1', etc) │              │
    └────────┬───────────────────────┘              │
             │                                      │
     ┌───────┴───────┬──────────────┬──────────────┬──────────┐
     │               │              │              │          │
     ▼               ▼              ▼              ▼          ▼
 Pattern:       Pattern:       Pattern:      Pattern:   Pattern:
 '1.1.x'        '1.2.x'        '2.x'         '3.x'      '4.x'/'5.x'
     │               │              │              │          │
     ▼               ▼              ▼              ▼          ▼
CHMOD/CHOWN    KUBELET CFG    ETCD CFG     CONTROL-    VARIOUS
             CHANGES         CHANGES       PLANE CFG
     │               │              │              │          │
     │               └──────────────┴──────────────┴──────────┘
     │                              │
     ▼                              ▼
┌──────────────────┐        ┌──────────────────┐
│  CLASSIFICATION  │        │  CLASSIFICATION  │
│                  │        │                  │
│ SAFE             │        │ REQUIRES HEALTH  │
│ Permission-only  │        │ Config/Service   │
│ No restarts      │        │ Service restarts │
└────────┬─────────┘        └────────┬─────────┘
         │                           │
         ▼                           ▼
    return (False,             return (True,
    "Safe...")                 "Config/Service...")
         │                           │
         ▼                           ▼
    [SKIP HEALTH      ┌──────► [PERFORM
     CHECK]           │         HEALTH CHECK]
                      │            │
                      │            ▼
                      │      ┌─────────────┐
                      │      │ TCP check   │
                      │      ├─────────────┤
                      │      │ readyz check│
                      │      ├─────────────┤
                      │      │ Settle time │
                      │      └──────┬──────┘
                      │             │
                      │      ┌──────┴───────┐
                      │      │              │
                      │      ▼              ▼
                      │   HEALTHY      UNHEALTHY
                      │      │              │
                      │      ▼              ▼
                      │  CONTINUE    EMERGENCY
                      │      │        BRAKE
                      │      │      (EXIT)
                      └──────┴──────┘
                             │
                             ▼
                        NEXT CHECK
```

---

## Health Check Decision Point

```
After each check execution:

                    ┌─ Check Status ─┐
                    │                │
          ┌─────────┴────────┐       │
          ▼                  ▼       │
       PASS/FIXED           SKIP     │
          │                  │       │
          ▼                  │       │
    ┌──────────────┐         │       │
    │ Proceed to   │         │       │
    │ Classification       │       │
    └────────┬─────┘        │       │
             │              │       │
             ▼              │       │
    ┌────────────────────┐  │       │
    │ requires_health    │  │       │
    │ _check?            │  │       │
    └────┬───────────────┘  │       │
         │                  │       │
    ┌────┴────┐             │       │
    │          │             │       │
    ▼          ▼             │       │
   TRUE      FALSE            │       │
    │          │             │       │
    │          ▼             │       │
    │     [SKIP & TRACK]    │       │
    │      Continue         │       │
    │                       │       │
    ▼                       │       │
┌──────────────────┐       │       │
│ Health Check:    │       │       │
│ 1. TCP port      │       │       │
│ 2. readyz        │       │       │
│ 3. Settle time   │       │       │
└────┬─────────────┘       │       │
     │                     │       │
  ┌──┴──┐                  │       │
  │     │                  │       │
  ▼     ▼                  │       │
PASS  FAIL                 │       │
  │     │                  │       │
  │     ▼                  │       │
  │  EMERGENCY             │       │
  │  BRAKE                 │       │
  │  (EXIT)                │       │
  │                        │       │
  └───────┬────────────────┘       │
          │                        │
          ├────────┬───────────────┘
          │        │
          ▼        ▼
      CONTINUE   SKIP
      (TRACK)   (TRACK)
          │        │
          └────┬───┘
               │
               ▼
          NEXT CHECK
```

---

## Output Timeline

```
Timeline of execution output with Smart Wait:

00:00  [*] Executing GROUP A - SEQUENTIAL mode (Smart Wait enabled)...
00:01  [Group A 1/30] Running: 1.1.1 (SEQUENTIAL)...
00:01      [Smart Wait] Safe (Permission/Ownership) - Skip Health Check
00:06      [OK] Safe operation (no health check needed). Continuing...

00:07  [Group A 2/30] Running: 1.1.2 (SEQUENTIAL)...
00:07      [Smart Wait] Safe (Permission/Ownership) - Skip Health Check
00:12      [OK] Safe operation (no health check needed). Continuing...

       ... (20 safe checks, ~5 seconds each) ...

02:40  [Group A 21/30] Running: 1.2.1 (SEQUENTIAL)...
02:40      [Smart Wait] Config/Service Changes - Full Health Check Required
02:41      [Health Check] Verifying cluster stability (config change detected)...
03:06      [OK] Cluster stable. Continuing to next Group A check...

       ... (10 config checks, ~30 seconds each including health check) ...

06:15  [*] GROUP A Final Stability Check (after 20 safe operations)...
06:15      Skipped health checks for: 1.1.1, 1.1.2, ..., 1.1.20
06:40      [OK] All GROUP A checks stable. Proceeding to GROUP B...

06:41  [GROUP A SUMMARY]
06:41      Health checks skipped: 20 (safe operations)
06:41      Health checks performed: 10 (config changes)
06:41      Final stability check: PASSED

06:41  [+] GROUP A (Critical/Config) Complete.
06:42  [*] Executing GROUP B (Resources) - PARALLEL mode...

       ... (Group B continues in parallel) ...
```

---

## Component Interaction Diagram

```
                         cis_k8s_unified.py
                         ==================
                              │
                ┌─────────────┬─────────────┐
                │             │             │
                ▼             ▼             ▼
         ┌─────────────┐ ┌─────────────┐ ┌──────────────┐
         │  New Method │ │  Modified   │ │ Unchanged    │
         │ (Lines      │ │   Loop      │ │   Methods    │
         │ 1100-1122)  │ │ (Lines      │ │              │
         │             │ │ 1158-1267)  │ │              │
         │             │ │             │ │              │
         │ Classify    │ │ Execute +   │ │ wait_for_   │
         │ check type  │ │ Conditional │ │ healthy_    │
         │             │ │ checks +    │ │ cluster()   │
         │ Safe/Risky  │ │ Final check │ │ (unchanged) │
         │             │ │             │ │              │
         └─────┬───────┘ └──────┬──────┘ └──────┬───────┘
               │                │               │
               └────────────────┼───────────────┘
                                │
                    Health Check Decision
                                │
                        ┌───────┴───────┐
                        │               │
                        ▼               ▼
                    Skip          Perform
                  (Safe Op)     (Config Op)
                        │               │
                        │               ▼
                        │          TCP Check
                        │              │
                        │              ▼
                        │         readyz Check
                        │              │
                        │              ▼
                        │          Settle Time
                        │              │
                        └──────┬───────┘
                               │
                               ▼
                        Next Check or
                        Final Check
```

---

## Legend

```
┌─────┐
│ Box │ - Process or Decision
└─────┘

──►  Arrow  - Flow direction
  ▼  Down arrow  - Next step
  │  Vertical line  - Sequential flow

[TEXT]  - Status or message
...     - Continuation (repeated pattern)
```

---

**Diagram Version**: 1.0  
**Purpose**: Visual understanding of Smart Wait implementation  
**Status**: ✅ Complete
