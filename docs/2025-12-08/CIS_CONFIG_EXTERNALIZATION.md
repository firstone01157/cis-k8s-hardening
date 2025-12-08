# CIS Configuration Externalization - Complete Reference

## Overview

This document provides a comprehensive guide to the new **centralized configuration system** for CIS Kubernetes hardening checks. The system externalizes all hardening parameters into `cis_config.json`, enabling easy customization without code changes.

---

## 1. Configuration File Structure

### File Location
```
/home/first/Project/cis-k8s-hardening/cis_config_comprehensive.json
```

### Top-Level Sections

| Section | Purpose | Example |
|---------|---------|---------|
| `_metadata` | Version info and timestamps | Version 1.0.0 |
| `excluded_rules` | Rules to skip completely | {"1.1.12": "RISK_ACCEPTED"} |
| `checks_config` | **NEW**: Per-check enable/disable + parameters | See below |
| `variables` | Centralized path & permission definitions | File paths, modes, owners |
| `remediation_config` | Global & per-check remediation settings | Backup, dry-run, timeout |
| `component_mapping` | Group checks by component | api_server, kubelet |
| `health_check` | Health check configuration | Services, ports, URLs |
| `logging` | Logging settings | Log directory, level |

---

## 2. NEW: checks_config Section

This section replaces hardcoded values in Python with externalized configuration.

### Structure

```json
{
  "checks_config": {
    "<CHECK_ID>": {
      "enabled": <boolean>,
      "_comment": "<explanation>",
      "check_type": "<file_permission|flag_check|...>",
      "field1": "<value1>",
      "field2": "<value2>"
    }
  }
}
```

### Example: Disable 5.3.2 (Network Policies)

```json
{
  "checks_config": {
    "5.3.2": {
      "enabled": false,
      "_comment": "Disabled for Safety First strategy - Network Policies can break cluster traffic",
      "reason": "Allow-all NetworkPolicies are a security anti-pattern. Enable only after implementing proper network segmentation policy.",
      "remediation": "manual"
    }
  }
}
```

**Result**: When Python runs check 5.3.2, it will:
1. Load this config
2. See `"enabled": false`
3. Skip execution immediately
4. Log: `[SKIP] 5.3.2: Disabled for Safety First strategy...`

### Example: File Permission Check (1.1.1)

```json
{
  "checks_config": {
    "1.1.1": {
      "enabled": true,
      "_comment": "API Server manifest file permissions",
      "check_type": "file_permission",
      "file_path": "/etc/kubernetes/manifests/kube-apiserver.yaml",
      "file_mode": "600",
      "_file_mode_default": "600",
      "file_owner": "root",
      "_file_owner_default": "root",
      "file_group": "root",
      "_file_group_default": "root",
      "remediation": "automated"
    }
  }
}
```

**Result**: When Python runs check 1.1.1, it will:
1. Load this config
2. Extract `file_mode`, `file_owner`, `file_group`, `file_path`
3. Inject into environment variables:
   - `FILE_MODE=600`
   - `FILE_OWNER=root`
   - `FILE_GROUP=root`
   - `FILE_PATH=/etc/kubernetes/manifests/kube-apiserver.yaml`
4. Pass these to the Bash script via subprocess environment

### Example: Flag Check (1.2.1)

```json
{
  "checks_config": {
    "1.2.1": {
      "enabled": true,
      "_comment": "API Server anonymous-auth flag",
      "check_type": "flag_check",
      "flag_name": "--anonymous-auth",
      "expected_value": "false",
      "remediation": "automated"
    }
  }
}
```

**Result**: When Python runs check 1.2.1, it will:
1. Load this config
2. Inject into environment variables:
   - `FLAG_NAME=--anonymous-auth`
   - `EXPECTED_VALUE=false`
3. Bash script uses these to validate/fix the flag

---

## 3. Shadow Keys Pattern

For documentation purposes, shadow keys (prefixed with `_`) provide defaults and explanations:

```json
{
  "file_mode": "600",
  "_file_mode_default": "600",
  "_file_mode_comment": "CIS L1.1.1 requires 600 for API server manifest"
}
```

**Rules**:
- Active keys: `file_mode`, `file_owner`, `file_path` (used by Python)
- Shadow keys: `_file_mode_default`, `_file_owner_comment` (documentation only)
- Python ignores keys starting with `_`

---

## 4. Python Code Changes

### Updated load_config() Method

```python
def load_config(self):
    # ... existing code ...
    
    # NEW: Load per-check configuration
    self.checks_config = config.get("checks_config", {})
    
    # ... rest of method ...
```

### New Helper Method: _get_check_config()

```python
def _get_check_config(self, check_id):
    """Retrieve check-specific config from JSON"""
    checks_config = getattr(self, 'checks_config', {})
    
    if check_id in checks_config:
        return checks_config[check_id]
    
    return {}  # Defaults to enabled if not found
```

### Modified run_script() Method

**Key Addition** - Check if enabled:

```python
def run_script(self, script, mode):
    script_id = script["id"]
    
    # STEP 1: Load check configuration
    check_config = self._get_check_config(script_id)
    
    # STEP 2: Check if enabled
    if not check_config.get("enabled", True):
        reason = check_config.get("_comment", "Check disabled in configuration")
        print(f"{Colors.YELLOW}[SKIP] {script_id}: {reason}{Colors.ENDC}")
        return self._create_result(script, "SKIPPED", reason, duration)
    
    # ... continue with existing logic ...
```

**Key Addition** - Inject environment variables:

```python
# In run_script(), in the remediation block:

# Extract configuration and inject as environment variables
if check_config:
    if check_config.get("check_type") == "file_permission":
        env["FILE_MODE"] = check_config.get("file_mode")
        env["FILE_OWNER"] = check_config.get("file_owner")
        env["FILE_GROUP"] = check_config.get("file_group")
        env["FILE_PATH"] = check_config.get("file_path")
    
    if check_config.get("check_type") == "flag_check":
        env["FLAG_NAME"] = check_config.get("flag_name")
        env["EXPECTED_VALUE"] = check_config.get("expected_value")

# Pass env to subprocess.run()
result = subprocess.run(["bash", script["path"]], env=env, ...)
```

---

## 5. How Bash Scripts Use Environment Variables

### File Permission Remediation Example

**Bash script: `1.1.1_remediate.sh`**

```bash
#!/bin/bash

# Use environment variables injected by Python
echo "[INFO] Applying file permissions to ${FILE_PATH}"

# Variables are automatically available:
# FILE_PATH=/etc/kubernetes/manifests/kube-apiserver.yaml
# FILE_MODE=600
# FILE_OWNER=root
# FILE_GROUP=root

chmod "${FILE_MODE}" "${FILE_PATH}" || {
    echo "[FAIL] chmod failed for ${FILE_PATH}"
    exit 1
}

chown "${FILE_OWNER}:${FILE_GROUP}" "${FILE_PATH}" || {
    echo "[FAIL] chown failed for ${FILE_PATH}"
    exit 1
}

echo "[PASS] File permissions applied successfully"
exit 0
```

### Flag Remediation Example

**Bash script: `1.2.1_remediate.sh`**

```bash
#!/bin/bash

# Use environment variables injected by Python
echo "[INFO] Setting ${FLAG_NAME} flag"

# Variables are automatically available:
# FLAG_NAME=--anonymous-auth
# EXPECTED_VALUE=false

# Update API server manifest
sed -i "s/.*${FLAG_NAME}.*/    - ${FLAG_NAME}=${EXPECTED_VALUE}/" /etc/kubernetes/manifests/kube-apiserver.yaml

echo "[PASS] Flag updated"
exit 0
```

---

## 6. Execution Flow

### Disabled Check (5.3.2)

```
User runs: python3 cis_k8s_unified.py
  ↓
Load cis_config.json
  ↓
Process check 5.3.2
  ↓
Call run_script({"id": "5.3.2", ...}, "remediate")
  ↓
_get_check_config("5.3.2")
  ↓
Returns: {"enabled": false, "_comment": "Disabled for Safety First..."}
  ↓
Check "enabled": false → SKIP immediately
  ↓
Print: [SKIP] 5.3.2: Disabled for Safety First strategy
  ↓
Return SKIPPED result
  ↓
Continue to next check
```

### Enabled File Permission Check (1.1.1)

```
User runs: python3 cis_k8s_unified.py
  ↓
Load cis_config.json
  ↓
Process check 1.1.1
  ↓
Call run_script({"id": "1.1.1", ...}, "remediate")
  ↓
_get_check_config("1.1.1")
  ↓
Returns: {
  "enabled": true,
  "file_path": "/etc/kubernetes/manifests/kube-apiserver.yaml",
  "file_mode": "600",
  "file_owner": "root"
}
  ↓
Check "enabled": true → CONTINUE
  ↓
Extract file_path, file_mode, file_owner
  ↓
Inject into env: FILE_PATH=..., FILE_MODE=..., FILE_OWNER=...
  ↓
Execute: subprocess.run(["bash", "1.1.1_remediate.sh"], env=env)
  ↓
Bash script receives env vars
  ↓
chmod ${FILE_MODE} ${FILE_PATH}
  ↓
chown ${FILE_OWNER}:${FILE_GROUP} ${FILE_PATH}
  ↓
Return PASS/FAIL result
```

---

## 7. Adding a New Check to Configuration

### Step 1: Add to checks_config

```json
{
  "checks_config": {
    "1.1.21": {
      "enabled": true,
      "_comment": "kubelet.conf file permissions",
      "check_type": "file_permission",
      "file_path": "/etc/kubernetes/kubelet.conf",
      "file_mode": "600",
      "_file_mode_default": "600",
      "file_owner": "root",
      "_file_owner_default": "root",
      "file_group": "root",
      "_file_group_default": "root",
      "remediation": "automated"
    }
  }
}
```

### Step 2: Update Bash Script

The Bash script automatically receives:
- `FILE_PATH=/etc/kubernetes/kubelet.conf`
- `FILE_MODE=600`
- `FILE_OWNER=root`
- `FILE_GROUP=root`

### Step 3: No Python Code Changes Needed!

The Python code automatically:
1. Loads the config
2. Injects the variables
3. Passes them to the script

---

## 8. Disabling Checks Temporarily

### Option 1: Set "enabled": false

```json
{
  "checks_config": {
    "5.3.2": {
      "enabled": false,
      "_comment": "Temporarily disabled for testing"
    }
  }
}
```

Python will skip this check silently.

### Option 2: Use excluded_rules

```json
{
  "excluded_rules": {
    "5.3.2": "TEMPORARY_TESTING"
  }
}
```

Python will skip with reason: "TEMPORARY_TESTING".

**Difference**:
- `checks_config.enabled`: Check not yet ready, needs parameters
- `excluded_rules`: Check excluded for business/risk reasons

---

## 9. Migration Guide

### Before (Hardcoded)

```bash
# File permissions hardcoded in scripts
chmod 600 /etc/kubernetes/manifests/kube-apiserver.yaml
chown root:root /etc/kubernetes/manifests/kube-apiserver.yaml
```

### After (Externalized)

**cis_config.json**:
```json
{
  "checks_config": {
    "1.1.1": {
      "file_mode": "600",
      "file_owner": "root"
    }
  }
}
```

**Bash script** (universal):
```bash
chmod "${FILE_MODE}" "${FILE_PATH}"
chown "${FILE_OWNER}:${FILE_GROUP}" "${FILE_PATH}"
```

**Benefits**:
- ✅ Single source of truth (JSON)
- ✅ No code changes needed for configuration updates
- ✅ Audit trail of settings
- ✅ Easy to version control

---

## 10. Shadow Keys Best Practices

| Pattern | Use Case | Example |
|---------|----------|---------|
| `key` | Active parameter used by Python | `"file_mode": "600"` |
| `_key_default` | Default value reference | `"_file_mode_default": "600 (CIS L1.1.1)"` |
| `_comment` | Human-readable explanation | `"_comment": "API server manifest permissions"` |
| `_reason` | Why something was disabled | `"_reason": "Safety First strategy"` |

**Rule**: Python ignores all keys starting with `_`.

---

## 11. Complete Config Example

See file: `/home/first/Project/cis-k8s-hardening/cis_config_comprehensive.json`

Key sections:
- `checks_config`: 5.3.2 (disabled), 1.1.1, 1.1.9, 1.1.11, 1.2.1, 1.2.2
- `variables`: Centralized paths and permissions
- `remediation_config.global`: Backup, dry-run, API timeout settings
- `remediation_config.checks`: Per-check remediation options
- `component_mapping`: Group checks by component

---

## 12. Debugging Configuration

### Enable verbose logging:

```bash
python3 cis_k8s_unified.py -vvv
```

### Check what config was loaded:

```bash
python3 -c "import json; f=open('cis_config.json'); print(json.dumps(json.load(f), indent=2))" | head -100
```

### Validate JSON syntax:

```bash
python3 -m json.tool cis_config.json > /dev/null && echo "Valid" || echo "Invalid"
```

### Trace a specific check:

```python
# In Python, add debug output
check_config = self._get_check_config("1.1.1")
print(f"Config for 1.1.1: {json.dumps(check_config, indent=2)}")
```

---

## 13. Summary

The new configuration system provides:

✅ **Centralized Control**: All checks configured in JSON  
✅ **Per-Check Enable/Disable**: Toggle checks without code changes  
✅ **Externalized Parameters**: File paths, modes, owners in config  
✅ **Environment Injection**: Variables passed to Bash scripts automatically  
✅ **Shadow Keys**: Documentation without affecting execution  
✅ **Backward Compatible**: Existing code still works; new features are opt-in  
✅ **Audit Trail**: Configuration changes tracked in JSON  

---

## 14. Files Delivered

1. **cis_config_comprehensive.json** - Complete configuration with all checks
2. **CONFIG_INTEGRATION_SNIPPET.py** - Python code snippets for integration
3. **CIS_CONFIG_EXTERNALIZATION.md** - This guide

---

## Questions?

Refer to the inline comments in:
- `CONFIG_INTEGRATION_SNIPPET.py` - Code examples
- `cis_config_comprehensive.json` - Configuration examples
