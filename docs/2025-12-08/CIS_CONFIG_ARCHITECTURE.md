# Configuration Externalization - Architecture & Flow

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CIS Kubernetes Hardening                         │
│                                                                      │
│  ┌──────────────────────┐      ┌──────────────────────┐            │
│  │  cis_config.json     │      │ cis_k8s_unified.py   │            │
│  │  (Configuration)     │      │ (Main Application)   │            │
│  │                      │      │                      │            │
│  │  checks_config:      │      │  load_config()       │            │
│  │  ├─ 5.3.2            │      │  ├─ Read JSON        │            │
│  │  │ enabled: false    │      │  └─ Parse configs    │            │
│  │  │ _comment: ...     │      │                      │            │
│  │  │                   │      │  run_script()        │            │
│  │  ├─ 1.1.1           │      │  ├─ Get check config │            │
│  │  │ enabled: true    │      │  ├─ Check if enabled │            │
│  │  │ file_path: ...   │      │  ├─ Inject vars      │            │
│  │  │ file_mode: 600   │      │  └─ Execute script   │            │
│  │  │ file_owner: root │      │                      │            │
│  │  └─ ...             │      │  _get_check_config() │            │
│  │                     │      │  └─ Lookup in config │            │
│  │ remediation_config: │      │                      │            │
│  │ ├─ global          │      │                      │            │
│  │ │ backup_enabled   │      │                      │            │
│  │ │ dry_run: false   │      │                      │            │
│  │ │ ...              │      │                      │            │
│  │ └─ checks          │      │                      │            │
│  │                     │      │                      │            │
│  └──────────────────────┘      └──────────────────────┘            │
│           △                              │                         │
│           │                              │                         │
│           └──────────────────────────────┘                         │
│                    (JSON load)                                      │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │              Environment Variable Injection                  │  │
│  │                                                               │  │
│  │  Check: 1.1.1                                               │  │
│  │  ├─ FILE_MODE=600                                          │  │
│  │  ├─ FILE_OWNER=root                                        │  │
│  │  ├─ FILE_GROUP=root                                        │  │
│  │  └─ FILE_PATH=/etc/kubernetes/manifests/kube-apiserver.yaml
│  │                                                               │  │
│  │  Check: 1.2.1                                               │  │
│  │  ├─ FLAG_NAME=--anonymous-auth                             │  │
│  │  └─ EXPECTED_VALUE=false                                   │  │
│  │                                                               │  │
│  └──────────────────────────────────────────────────────────────┘  │
│           △                                                         │
│           │                                                         │
│           └──────────────────────┬──────────────────────┐           │
│                                  ▼                      ▼           │
│                      ┌──────────────────┐    ┌──────────────────┐  │
│                      │  1.1.1_remediate │    │ 1.2.1_remediate  │  │
│                      │      .sh         │    │      .sh         │  │
│                      │                  │    │                  │  │
│                      │ chmod $FILE_MODE │    │ Set --anon-auth  │  │
│                      │ chown $FILE_OWNER│    │ to $EXPECTED_VAL │  │
│                      │ $FILE_PATH       │    │                  │  │
│                      └──────────────────┘    └──────────────────┘  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Data Flow Diagram

```
User runs Python application
         │
         ▼
    ┌─────────────────────────────────────────────┐
    │ load_config()                               │
    │                                             │
    │ 1. Open cis_config.json                     │
    │ 2. Parse JSON                              │
    │ 3. Load checks_config section               │
    │ 4. Store in self.checks_config dict         │
    └─────────────────────────────────────────────┘
         │
         ▼ (For each check)
    ┌─────────────────────────────────────────────┐
    │ run_script(check_id, mode)                  │
    │                                             │
    │ 1. Get script_id                           │
    │ 2. Call _get_check_config(script_id)       │
    └─────────────────────────────────────────────┘
         │
         ▼
    ┌─────────────────────────────────────────────┐
    │ _get_check_config()                         │
    │                                             │
    │ return self.checks_config[check_id]         │
    └─────────────────────────────────────────────┘
         │
         ▼ (check_config dict)
    ┌─────────────────────────────────────────────┐
    │ Check if check_config["enabled"] == true    │
    │                                             │
    │ IF False:                                   │
    │   - Log: CHECK_DISABLED                     │
    │   - Print: [SKIP] <reason>                  │
    │   - Return SKIPPED result                   │
    │   - Go to next check ──────────┐            │
    │                                │            │
    │ IF True or not set:            │            │
    │   - Continue ──────────┐       │            │
    │                        │       │            │
    └────────────────────────┼───────┼────────────┘
                             │       │
                             ▼       │
            ┌──────────────────────┐ │
            │ Prepare environment  │ │
            │ Extract from config: │ │
            │  - FILE_MODE         │ │
            │  - FILE_OWNER        │ │
            │  - FILE_GROUP        │ │
            │  - FILE_PATH         │ │
            │  - FLAG_NAME         │ │
            │  - EXPECTED_VALUE    │ │
            │                      │ │
            │ Inject into env dict │ │
            └──────────────────────┘ │
                     │                │
                     ▼                │
            ┌──────────────────────┐ │
            │ subprocess.run()     │ │
            │  - bash script_path  │ │
            │  - env=env (injected)│ │
            │  - capture_output    │ │
            └──────────────────────┘ │
                     │                │
                     ▼                │
            ┌──────────────────────┐ │
            │ Bash Script          │ │
            │                      │ │
            │ #!/bin/bash          │ │
            │ echo "FILE_MODE      │ │
            │ chmod $FILE_MODE...  │ │
            │ exit 0               │ │
            └──────────────────────┘ │
                     │                │
                     ▼                │
            ┌──────────────────────┐ │
            │ Subprocess returns   │ │
            │ stdout, stderr, code │ │
            └──────────────────────┘ │
                     │                │
                     ▼                │
            ┌──────────────────────┐ │
            │ _parse_script_output │ │
            │ Determine result     │ │
            │ PASS/FAIL/FIXED      │ │
            └──────────────────────┘ │
                     │                │
                     ▼                │
            ┌──────────────────────┐ │
            │ Return result dict   │ │
            └──────────────────────┘ │
                     │                │
         ┌───────────┘                │
         │                            │
         ▼ (next check)               │
    ┌─────────────────────────────┐   │
    │ Continue loop...             │   │
    └─────────────────────────────┘   │
                                      │
         ┌────────────────────────────┘
         │
         ▼ (check disabled)
    ┌──────────────────────────────┐
    │ [SKIP] result                │
    │ Status: SKIPPED              │
    │ Reason: "Disabled in config" │
    └──────────────────────────────┘
         │
         ▼
    ┌──────────────────────────────┐
    │ Continue to next check...    │
    └──────────────────────────────┘
```

---

## Configuration Lookup Sequence

```
Start: script_id = "1.1.1"
       │
       ▼
    ┌─────────────────────────────────────────┐
    │ _get_check_config("1.1.1")              │
    │                                         │
    │ if "1.1.1" in self.checks_config:       │
    │   return self.checks_config["1.1.1"]    │
    │ else:                                   │
    │   return {}                             │
    └─────────────────────────────────────────┘
       │
       ├─ Check Found ──────────────────┐
       │                                │
       ▼                                ▼
    Config Dict            Empty Dict (no override)
    ┌──────────────────┐   ┌────────────┐
    │ {                │   │ {}         │
    │ "enabled": true, │   │            │
    │ "file_mode":     │   │ Default:   │
    │   "600",         │   │ enabled=   │
    │ "file_owner":    │   │ true       │
    │   "root",        │   │            │
    │ ...              │   └────────────┘
    │ }                │
    └──────────────────┘
       │
       ▼
    ┌──────────────────────────────────────┐
    │ check_config.get("enabled", True)    │
    │                                      │
    │ If key exists: use value             │
    │ If key missing: use default (True)   │
    └──────────────────────────────────────┘
       │
       ├─ enabled: true ────────────────────┐
       │                                    │
       │ Continue execution                 │
       │ Proceed to environment injection   │
       │                                    │
       ▼                                    ▼
    Extract config values               [SKIP result]
    Inject into environment
```

---

## Configuration Sections Hierarchy

```
cis_config.json
├── _metadata
│   ├── version
│   ├── description
│   └── last_updated
│
├── excluded_rules
│   └── {check_id: reason, ...}
│
├── checks_config  ◄── NEW SECTION
│   └── {check_id: {
│         "enabled": boolean,
│         "_comment": string,
│         "check_type": string,
│         ...parameters...
│       }, ...}
│
├── variables
│   ├── kubernetes_paths
│   ├── file_permissions
│   ├── file_ownership
│   ├── api_server_flags
│   ├── kubelet_config_params
│   └── audit_configuration
│
├── remediation_config
│   ├── global
│   │   ├── backup_enabled
│   │   ├── backup_dir
│   │   ├── dry_run
│   │   └── wait_for_api
│   ├── environment_overrides
│   │   └── {...}
│   └── checks
│       └── {check_id: {...}, ...}
│
├── component_mapping
│   └── {component: [check_id, ...], ...}
│
├── health_check
│   ├── check_services
│   ├── check_ports
│   └── api_health_url
│
└── logging
    ├── enabled
    ├── log_dir
    └── level
```

---

## Decision Tree - Should Check Be Skipped?

```
                         ┌─────────────────────────┐
                         │ run_script() called     │
                         └────────────┬────────────┘
                                      │
                         ┌────────────▼────────────┐
                         │ Load check_config       │
                         │ from JSON               │
                         └────────────┬────────────┘
                                      │
                     ┌────────────────▼────────────────────┐
                     │ check_config.get("enabled", True)   │
                     └─┬──────────────────────────────────┬┘
                       │                                  │
                  False│                              True│/Not set
                       │                                  │
          ┌────────────▼─────────────┐    ┌──────────────▼──────────┐
          │ [SKIP] Check disabled    │    │ Continue execution      │
          │                          │    │                         │
          │ Status: SKIPPED          │    │ Check is_rule_excluded? │
          │ Reason: <_comment>       │    └────┬───────────────┬───┘
          │                          │         │               │
          │ Return result            │    Yes  │           No  │
          └────────────┬─────────────┘         │               │
                       │              ┌────────▼──────────┐    │
                       │              │ [IGNORE] Check    │    │
                       │              │ is excluded       │    │
                       │              │                   │    │
                       │              │ Status: IGNORED   │    │
                       │              │                   │    │
                       │              │ Return result     │    │
                       │              └────────┬──────────┘    │
                       │                       │               │
                       │                       │     ┌─────────▼─────────────┐
                       │                       │     │ Continue with audit/  │
                       │                       │     │ remediation logic     │
                       │                       │     │                       │
                       │                       │     │ Check if manual       │
                       │                       │     └─────────────┬─────────┘
                       │                       │                   │
                       └───────────────┬───────┴───────────────────┘
                                       │
                                       ▼
                          (Next check or complete)
```

---

## Check Type Processing

```
check_config loaded from JSON
       │
       ▼
check_config.get("check_type")
       │
       ├─ "file_permission" ──────────────────┐
       │                                      │
       ├─ "flag_check" ──────────────────┐   │
       │                                │   │
       ├─ "config_check" ──────────────┐│   │
       │                               ││   │
       └─ null/missing ────────────────┐││  │
                                       │││  │
        ┌──────────────────────────────┘││  │
        │    ┌────────────────────────────┘│  │
        │    │    ┌───────────────────────┘│  │
        │    │    │    ┌─────────────────┘│  │
        ▼    ▼    ▼    ▼                  │  │
                                          │  │
      FILE_PERMISSION              FLAG_CHECK  CONFIG_CHECK  UNKNOWN
      Processing                   Processing  Processing    Processing
      ┌──────────────────┐        ┌────────┐  ┌──────────┐   ┌────────┐
      │ Extract:         │        │Extract:│  │Extract:  │   │No env  │
      │ - FILE_MODE      │        │- FLAG_ │  │- CONFIG_ │   │vars    │
      │ - FILE_OWNER     │        │ NAME   │  │ PARAMS   │   │injected│
      │ - FILE_GROUP     │        │- EXPEC │  │          │   │        │
      │ - FILE_PATH      │        │ TED_VAL│  │          │   │        │
      │                  │        │        │  │          │   │        │
      │ Inject env vars: │        │Inject: │  │Inject:   │   │        │
      │ FILE_*=...       │        │FLAG_*=.│  │CONFIG_*=.│   │        │
      └──────────────────┘        └────────┘  └──────────┘   └────────┘
            │                          │          │              │
            └──────────────┬───────────┴──────────┴──────────────┘
                           │
                    ▼ subprocess.run()
             (Pass env with injected vars)
```

---

## Environment Variable Naming Convention

```
Source: cis_config.json                    Result: Environment Variable
────────────────────────────────────────────────────────────────────

checks_config[check_id]:
  - file_path                    ──────►   FILE_PATH
  - file_mode                    ──────►   FILE_MODE
  - file_owner                   ──────►   FILE_OWNER
  - file_group                   ──────►   FILE_GROUP
  - flag_name                    ──────►   FLAG_NAME
  - expected_value               ──────►   EXPECTED_VALUE

remediation_config.checks[check_id]:
  - file_path                    ──────►   CONFIG_FILE_PATH
  - file_mode                    ──────►   CONFIG_FILE_MODE
  - backup_enabled               ──────►   CONFIG_BACKUP_ENABLED
  - <any key>                    ──────►   CONFIG_<KEY_UPPERCASE>

Global remediation_config.global:
  - backup_enabled               ──────►   BACKUP_ENABLED
  - backup_dir                   ──────►   BACKUP_DIR
  - dry_run                      ──────►   DRY_RUN
  - wait_for_api                 ──────►   WAIT_FOR_API

(Keys starting with _ are ignored by Python)
```

---

## Execution Timeline - Disabled Check

```
T=0ms    User: python3 cis_k8s_unified.py
         
T=50ms   Main: load_config()
         Load: cis_config.json
         Store: checks_config = {...}

T=100ms  Main: Main loop iterates
         Process: Check 5.3.2

T=120ms  run_script({"id": "5.3.2", ...}, mode)
         
T=125ms  _get_check_config("5.3.2")
         Lookup: self.checks_config["5.3.2"]
         Found: {"enabled": false, "_comment": "..."}
         Return: check_config dict

T=130ms  Check: if not check_config.get("enabled", True)
         Result: False (enabled is false)
         
T=135ms  Action: Skip execution
         - log_activity("CHECK_DISABLED", ...)
         - print("[SKIP] 5.3.2: ...")

T=140ms  Return: _create_result(..., "SKIPPED", reason, duration=15ms)

T=145ms  Result: {"id": "5.3.2", "status": "SKIPPED", ...}

T=150ms  Main: Continue to next check (5.3.3)
```

---

## Execution Timeline - Enabled File Check

```
T=0ms    User: python3 cis_k8s_unified.py
         
T=50ms   Main: load_config()
         Load: cis_config.json
         Store: checks_config = {...}

T=100ms  Main: Main loop iterates
         Process: Check 1.1.1

T=120ms  run_script({"id": "1.1.1", ...}, "remediate")
         
T=125ms  _get_check_config("1.1.1")
         Lookup: self.checks_config["1.1.1"]
         Found: {"enabled": true, "file_path": "/etc/...", "file_mode": "600", ...}
         Return: check_config dict

T=130ms  Check: if not check_config.get("enabled", True)
         Result: True (enabled is true, proceed)

T=135ms  Prepare environment
         Extract: file_mode="600", file_owner="root", file_path="/etc/..."
         Inject: env["FILE_MODE"]="600", env["FILE_OWNER"]="root", ...

T=140ms  subprocess.run(["bash", "1.1.1_remediate.sh"], env=env, ...)

T=145ms  Bash script starts
         Read: $FILE_MODE = "600"
         Read: $FILE_OWNER = "root"
         Read: $FILE_PATH = "/etc/kubernetes/manifests/kube-apiserver.yaml"

T=150ms  Bash executes:
         chmod "600" "/etc/kubernetes/manifests/kube-apiserver.yaml"
         chown "root:root" "/etc/kubernetes/manifests/kube-apiserver.yaml"

T=300ms  Bash exits with code 0 (success)

T=305ms  Python: _parse_script_output()
         Return code: 0 → status = "FIXED"

T=310ms  Return: {"id": "1.1.1", "status": "FIXED", "duration": 190ms, ...}

T=315ms  Main: Continue to next check
```

---

## Summary

The configuration externalization system provides a clean separation between:

1. **Static Configuration** (cis_config.json) - What to do, how to do it
2. **Python Logic** (cis_k8s_unified.py) - How to execute and orchestrate
3. **Bash Scripts** - Implementation details that use injected variables

This allows:
- ✅ Changes to configuration without code modifications
- ✅ Per-check enable/disable without touching Python
- ✅ Centralized parameter management
- ✅ Easy auditing and version control
- ✅ Environment-specific configurations

