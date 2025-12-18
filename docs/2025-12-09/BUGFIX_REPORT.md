# Critical Bug Fixes - CIS K8s Unified Runner

## Overview
Three critical bugs were causing FALSE POSITIVE audit results and remediation failures in `cis_k8s_unified.py`. These have been identified and fixed.

---

## Bug #1: KUBECONFIG Not Exported to Subprocess

### Symptom
- Kubectl commands failed with: `dial tcp 127.0.0.1:8080`
- Remediation scripts (e.g., 5.3.2) couldn't connect to the API server
- KUBECONFIG was detected in `load_config()` but not passed to child processes

### Root Cause
The `run_script()` method created a subprocess environment with `env = os.environ.copy()`, but:
1. KUBECONFIG detection logic was only in `get_kubectl_cmd()`
2. The KUBECONFIG path was never explicitly added to the `env` dictionary passed to `subprocess.run()`
3. Bash scripts inherited the parent shell's KUBECONFIG, which might not be set

### Fix Applied
```python
# CRITICAL FIX #1: Explicitly add KUBECONFIG to all subprocess calls
kubeconfig_paths = [
    os.environ.get('KUBECONFIG'),
    "/etc/kubernetes/admin.conf",
    os.path.expanduser("~/.kube/config"),
    f"/home/{os.environ.get('SUDO_USER', '')}/.kube/config"
]
for config_path in kubeconfig_paths:
    if config_path and os.path.exists(config_path):
        env["KUBECONFIG"] = config_path
        if self.verbose >= 2:
            print(f"{Colors.BLUE}[DEBUG] Set KUBECONFIG={config_path}{Colors.ENDC}")
        break
```

**Location:** `run_script()` method, line ~760

---

## Bug #2: Double Quoting of String Values

### Symptom
- Bash errors: `stat: cannot statx '"/etc/kubernetes/admin.conf"'`
- File paths had extra quote characters in the variable value
- JSON parsing was not stripping quotes from string values

### Root Cause
When exporting values from the JSON config to environment variables:
1. String values were converted with `str(value)`
2. If the JSON value was already a quoted string (e.g., `"/etc/kubernetes/admin.conf"`), the quotes were included
3. Bash scripts then received `"/etc/kubernetes/admin.conf"` instead of `/etc/kubernetes/admin.conf`

### Fix Applied
```python
# CRITICAL FIX #3: Type casting and quote stripping
if isinstance(value, bool):
    # Booleans: True -> "true", False -> "false" (lowercase for bash)
    env[env_key] = "true" if value else "false"
elif isinstance(value, (list, dict)):
    # Complex types: convert to JSON string (no extra quotes)
    env[env_key] = json.dumps(value)
elif isinstance(value, (int, float)):
    # Numbers: convert to string
    env[env_key] = str(value)
elif value is None:
    # None values: empty string
    env[env_key] = ""
else:
    # Strings: strip any leading/trailing quotes that JSON might have
    str_value = str(value)
    # Remove JSON quote characters if present
    if str_value.startswith('"') and str_value.endswith('"'):
        str_value = str_value[1:-1]
    env[env_key] = str_value
```

**Location:** `run_script()` method, line ~780-795

---

## Bug #3: Check Configuration Not Exported to Bash

### Symptom
- Bash scripts received `l_mode=` (empty values)
- `permission denied` errors on file operations because FILE_MODE was empty
- Scripts couldn't access check parameters like owner, file_mode, config_file, etc.

### Root Cause
The original code used a `CONFIG_` prefix for all environment variables and only exported them **during remediate mode**:
```python
# OLD CODE (WRONG)
env_key = f"CONFIG_{key.upper()}"  # Results in CONFIG_FILE_MODE, CONFIG_OWNER, etc.
```

Problems:
1. Audit scripts didn't receive any check config (only remediate did)
2. The prefix made variables harder to use in bash (longer names, inconsistent)
3. Metadata keys weren't properly filtered

### Fix Applied
1. **Removed the `CONFIG_` prefix** - Export variables directly with their key names in UPPERCASE:
   - `file_mode` → `FILE_MODE` (not `CONFIG_FILE_MODE`)
   - `owner` → `OWNER` (not `CONFIG_OWNER`)
   - `config_file` → `CONFIG_FILE` (not `CONFIG_CONFIG_FILE`)

2. **Export for both audit AND remediate** - All scripts can now access check config:
```python
# For both audit and remediate modes
for key, value in remediation_cfg.items():
    # Skip metadata keys / ข้ามคีย์ข้อมูลเมตา
    if key.startswith('_') or key in ['skip', 'enabled', 'id', 'path', 'role', 'level', 'requires_health_check']:
        continue
    
    # Convert to UPPERCASE for bash
    env_key = key.upper()
    
    # Apply type conversion and quote stripping (see Bug #2 fix)
    [... type conversion logic ...]
    
    env[env_key] = converted_value
```

3. **Extended to audit scripts** - Previously only remediate scripts got config:
```python
# Also export check config for audit scripts
if mode == "audit":
    # For audit scripts, also export check config (helpful for debugging)
    remediation_cfg = self.get_remediation_config_for_check(script_id)
    if remediation_cfg:
        [... same export logic ...]
```

**Location:** `run_script()` method, line ~777-832

---

## Summary of Changes

| Issue | Before | After |
|-------|--------|-------|
| KUBECONFIG | Not exported to subprocess | Explicitly added to `env` dict |
| Quote handling | Strings included JSON quotes | Quotes stripped before export |
| Variable naming | `CONFIG_FILE_MODE` | `FILE_MODE` |
| Audit mode exports | No check config exported | Check config exported |
| Type conversion | Simple `str()` conversion | Proper bool/int/JSON handling |

---

## Testing

### Test Commands

1. **Validate Python syntax:**
   ```bash
   python3 -m py_compile cis_k8s_unified.py
   ```

2. **Run a quick audit to verify environment exports:**
   ```bash
   python3 cis_k8s_unified.py -vv 2>&1 | grep -E "\[DEBUG\].*=.*"
   ```

3. **Check remediation on a single check:**
   ```bash
   # Run level 1 master node remediation with verbose output
   python3 cis_k8s_unified.py -vv
   # Select: Remediate → Level 1 → Master Node
   ```

### Expected Behavior

✓ KUBECONFIG debug output shows the correct path  
✓ Environment variables are exported with clean values (no extra quotes)  
✓ FILE_MODE, OWNER, and other variables have actual values (not empty)  
✓ Bash scripts can access `$FILE_MODE`, `$OWNER`, etc. correctly  
✓ Kubectl commands work without "dial tcp" errors  

---

## Integration with Previous Changes

These fixes work WITH the reference resolution system added in the previous refactoring:

1. `load_config()` loads the variables section
2. `_resolve_references()` fills in `_ref` values (e.g., `_required_value` gets the actual value)
3. `run_script()` now exports ALL check config values to bash with proper type conversion

This creates a complete pipeline:
```
JSON Config → Python Object → Environment Variables → Bash Script
```

---

## Files Modified

- **`cis_k8s_unified.py`**
  - `run_script()` method: Lines ~760-832
  - Explicit KUBECONFIG export
  - Proper type conversion and quote stripping
  - Export for both audit and remediate modes

---

## Notes for Bash Scripts

Bash scripts can now use variables like:

```bash
#!/bin/bash
# OLD (wouldn't work):
# stat -c '%a %U:%G' "$CONFIG_FILE_MODE"  # WRONG: variable name too long

# NEW (works correctly):
stat -c '%a %U:%G' "$CONFIG_FILE"  # Correct: clean variable name
chmod "$FILE_MODE" "$CONFIG_FILE"  # FILE_MODE has value "600", not empty
chown "$OWNER" "$CONFIG_FILE"      # OWNER has value "root:root", not empty
```

---

## Verification Checklist

- [x] Python syntax validates
- [x] KUBECONFIG explicitly exported to subprocess env
- [x] String values stripped of JSON quote characters
- [x] Boolean values converted to lowercase "true"/"false"
- [x] Variable names use UPPERCASE without CONFIG_ prefix
- [x] Audit scripts receive check config (not just remediate)
- [x] Type conversion handles bool, int, list, dict, None properly
- [x] Reference resolution integrated (from previous refactoring)

