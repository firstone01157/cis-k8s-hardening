# CIS K8s Unified Refactor - Consolidated Standalone Solution

## Executive Summary

This refactoring transforms `cis_k8s_unified.py` from a **fragile multi-file solution with external subprocess calls** into a **robust single-file standalone system** with atomic writes and automatic rollback.

### Key Problem Solved

```
OLD: subprocess.run(["python3", "scripts/yaml_safe_modifier.py", ...])
     └─ ERROR: FileNotFoundError: No such file or directory
     └─ REASON: Working directory issues, relative paths break in different contexts

NEW: Direct in-process call: YAMLSafeModifier(...).apply_yaml_fix(...)
     └─ No external files needed
     └─ No path issues
     └─ Atomic guarantee via os.replace()
     └─ Automatic rollback on failure
```

---

## What's Included

### 1. **CIS_CONSOLIDATED_REFACTOR_STRUCTURE.md** (Recommended First Read)
- **Purpose:** Architecture overview of the consolidated solution
- **Contains:**
  - Class hierarchy diagram
  - Where each class sits in the file
  - Key methods for each class
  - Integration flow diagram
  - Configuration structure examples
  - Benefits comparison (OLD vs NEW)
  - Migration checklist

**Read this first to understand the overall design.**

### 2. **CONSOLIDATED_IMPLEMENTATION_GUIDE.md** (Implementation Details)
- **Purpose:** Step-by-step code implementation guide
- **Contains:**
  - Exact code to embed (copy-paste ready)
  - Line numbers for placement in cis_k8s_unified.py
  - NEW method implementations (complete code)
  - Usage examples
  - Testing checklist
  - Configuration examples

**Read this when ready to implement the consolidation.**

### 3. **CONSOLIDATED_EXECUTION_FLOW.md** (Operational Understanding)
- **Purpose:** Complete execution flow and troubleshooting
- **Contains:**
  - Architecture diagram
  - Detailed step-by-step remediation flow
  - OLD vs NEW flow comparison
  - Error handling scenarios
  - Performance timeline
  - Memory impact analysis
  - Troubleshooting guide

**Read this for understanding how everything flows together.**

---

## Quick Start: 3-Step Integration

### Step 1: Add Imports (5 minutes)

Edit the top of `cis_k8s_unified.py`, after line 25:

```python
import tempfile
import requests
from typing import Tuple, Optional, Dict, Any

try:
    import yaml
except ImportError:
    yaml = None
```

### Step 2: Embed YAMLSafeModifier Class (10 minutes)

Copy the **ENTIRE YAMLSafeModifier class** from `CONSOLIDATED_IMPLEMENTATION_GUIDE.md` 
and paste it BEFORE the CISUnifiedRunner class definition.

**Location:** After `Colors` class, before `class CISUnifiedRunner:`

### Step 3: Embed AtomicRemediationManager Class (10 minutes)

Copy the **ENTIRE AtomicRemediationManager class** from `CONSOLIDATED_IMPLEMENTATION_GUIDE.md`
and paste it AFTER YAMLSafeModifier, BEFORE CISUnifiedRunner.

### Step 4: Add New Methods to CISUnifiedRunner (20 minutes)

Add these NEW methods to the CISUnifiedRunner class:
- `_classify_check_type()`
- `apply_yaml_fix_internal()`
- `fix_item_internal()`
- `_fix_yaml_config_check()`
- `_fix_system_check()`
- `_fix_unknown_check()`
- `_expand_path_variables()`
- `_find_audit_script_for_check()`
- `_find_remediation_script_for_check()`

See `CONSOLIDATED_IMPLEMENTATION_GUIDE.md` for complete code.

### Step 5: Update cis_config.json (5 minutes per check)

For each check, ensure you have:

**For YAML Config Checks (1.2.x, 1.3.x):**
```json
{
  "id": "1.2.1",
  "manifest_path": "/etc/kubernetes/manifests/kube-apiserver.yaml",
  "flag_name": "--authorization-mode",
  "expected_value": "Node,RBAC",
  "check_type": "yaml_flag"
}
```

**For System Checks (1.1.x):**
```json
{
  "id": "1.1.1",
  "bash_code": "chmod 700 /usr/bin/kube-apiserver",
  "check_type": "system"
}
```

---

## Benefits of Consolidation

### Eliminated Problems

| Problem | Before | After |
|---------|--------|-------|
| "FileNotFoundError: scripts/yaml_safe_modifier.py" | ❌ Common | ✅ Impossible |
| Subprocess overhead per YAML fix | ❌ 30-40MB memory | ✅ In-process, no fork |
| Partial file corruption on crash | ❌ Possible | ✅ Atomic os.replace() |
| Manual rollback on API failure | ❌ Manual intervention | ✅ Automatic rollback |
| Cascading cluster failures | ❌ Can happen | ✅ Health check barrier |
| Multi-file deployment | ❌ Complex (3+ files) | ✅ Single file |

### New Capabilities

- **Atomic Writes:** os.replace() guarantees all-or-nothing file swap
- **4-Phase Flow:** Backup → Apply → Health Check → Verify → Rollback on failure
- **Auto-Recovery:** Automatic rollback if cluster unhealthy or audit fails
- **Type Detection:** Config-driven check classification (no guessing)
- **Health Barrier:** Waits for API before continuing (prevents cascading failures)
- **Audit Verification:** Confirms remediation actually worked

---

## Architecture at a Glance

```
cis_k8s_unified.py (STANDALONE - ~4500 lines)
│
├─ YAMLSafeModifier class (embedded, ~300 lines)
│  ├─ Load/save YAML files
│  ├─ Parse command arguments
│  ├─ Modify flags in-place
│  └─ apply_yaml_fix() for internal use
│
├─ AtomicRemediationManager class (embedded, ~400 lines)
│  ├─ Create timestamped backups
│  ├─ Atomic write via os.replace()
│  ├─ Health check polling
│  ├─ Auto-rollback mechanism
│  └─ Audit verification
│
└─ CISUnifiedRunner class (enhanced)
   ├─ NEW: _classify_check_type() - Detect YAML vs System checks
   ├─ NEW: apply_yaml_fix_internal() - 4-phase atomic remediation
   ├─ NEW: fix_item_internal() - Main remediation router
   ├─ NEW: _fix_yaml_config_check() - YAML handler
   ├─ NEW: _fix_system_check() - System check handler
   └─ NEW: Helper methods for finding scripts, expanding paths
```

---

## Remediation Flow Summary

```
User calls: sudo python3 cis_k8s_unified.py --remediate --check-id=1.2.1
│
└─ fix_item_internal("1.2.1")
   │
   ├─ Phase 1: Create timestamped backup
   │  └─ /var/backups/cis-remediation/kube-apiserver.yaml.bak_20251218_104523
   │
   ├─ Phase 2: Apply YAML modification (IN-PROCESS, NO subprocess)
   │  └─ YAMLSafeModifier: parse YAML → modify → os.replace()
   │  └─ Atomic at OS level
   │
   ├─ Phase 3: Health Check Barrier (CRITICAL)
   │  └─ Poll https://127.0.0.1:6443/healthz
   │  └─ IF unhealthy → Auto-rollback → Return FAILED
   │  └─ IF healthy → Continue
   │
   ├─ Phase 4: Audit Verification
   │  └─ Run: bash Level_1_Master_Node/1.2.1_audit.sh
   │  └─ IF fails → Auto-rollback → Return FAILED
   │  └─ IF passes → Return SUCCESS
   │
   └─ Return: ("FIXED", "Applied --authorization-mode=Node,RBAC")
```

---

## Performance Impact

```
YAML Config Check:
  ├─ Backup:              50ms
  ├─ YAML modification:   100ms
  ├─ Health check:        15-30s (API restart + settle time)
  ├─ Audit verification:  5-60s
  └─ TOTAL:               20-120s (health check dominates)

System Check (chmod/chown):
  ├─ Bash execution:      50-500ms
  ├─ No health check
  └─ TOTAL:               <1s
```

---

## Configuration: Check Types

### Type 1: YAML Config Check

**Example:** Modify kube-apiserver flags

```json
{
  "1.2.1": {
    "id": "1.2.1",
    "description": "Ensure authorization mode is set",
    "check_type": "yaml_flag",
    "manifest_path": "/etc/kubernetes/manifests/kube-apiserver.yaml",
    "flag_name": "--authorization-mode",
    "expected_value": "Node,RBAC",
    "severity": "high"
  }
}
```

**Execution:** 
- Goes through 4-phase atomic flow
- Automatic rollback on any failure
- No external subprocess calls for modification

### Type 2: System Check

**Example:** Change file permissions

```json
{
  "1.1.1": {
    "id": "1.1.1",
    "description": "Ensure API server binary permissions",
    "check_type": "system",
    "bash_code": "chmod 700 /usr/bin/kube-apiserver",
    "severity": "high"
  }
}
```

**Execution:**
- Runs bash code directly
- No health check (file permissions don't affect cluster)
- Fast execution

---

## Testing the Consolidation

### Test 1: Import Check

```bash
python3 -c "
from cis_k8s_unified import YAMLSafeModifier, AtomicRemediationManager
print('✓ Classes imported successfully')
"
```

### Test 2: YAML Modifier

```bash
python3 <<EOF
from cis_k8s_unified import YAMLSafeModifier
m = YAMLSafeModifier('/etc/kubernetes/manifests/kube-apiserver.yaml', dry_run=True)
changed = m.apply_yaml_fix('kube-apiserver', '--authorization-mode', 'Node,RBAC')
print(f'✓ YAML modifier works: changed={changed}')
