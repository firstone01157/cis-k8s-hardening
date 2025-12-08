# Quick Implementation Guide - Configuration Externalization

## TLDR: What You Need to Do

### 1. Update Your cis_config.json (or use cis_config_comprehensive.json)

Add the `checks_config` section:

```json
{
  "checks_config": {
    "5.3.2": {
      "enabled": false,
      "_comment": "Disabled for Safety First strategy"
    },
    "1.1.1": {
      "enabled": true,
      "check_type": "file_permission",
      "file_path": "/etc/kubernetes/manifests/kube-apiserver.yaml",
      "file_mode": "600",
      "file_owner": "root",
      "file_group": "root"
    }
  }
}
```

### 2. Update cis_k8s_unified.py

Add these three components:

#### A. Update load_config() method (around line 107)

```python
def load_config(self):
    # ... existing code ...
    
    # NEW LINE: Add this
    self.checks_config = config.get("checks_config", {})
    
    # ... rest of existing code ...
```

#### B. Add new helper method _get_check_config()

```python
def _get_check_config(self, check_id):
    """Retrieve check-specific config from JSON"""
    checks_config = getattr(self, 'checks_config', {})
    
    if check_id in checks_config:
        return checks_config[check_id]
    
    return {}
```

#### C. Update run_script() method (around line 585)

**AFTER** the `is_rule_excluded()` check and **BEFORE** the existing try block:

```python
    def run_script(self, script, mode):
        # ... existing code up to here ...
        
        if self.stop_requested:
            return None
        
        start_time = time.time()
        script_id = script["id"]
        
        # =================================================================
        # NEW: STEP 1 - Load check configuration
        # =================================================================
        check_config = self._get_check_config(script_id)
        
        # =================================================================
        # NEW: STEP 2 - Check if this check is enabled
        # =================================================================
        if not check_config.get("enabled", True):
            reason = check_config.get("_comment", "Check disabled in configuration")
            self.log_activity("CHECK_DISABLED", f"Check {script_id}: {reason}")
            print(f"{Colors.YELLOW}[SKIP] {script_id}: {reason}{Colors.ENDC}")
            
            return self._create_result(
                script, 
                "SKIPPED",
                f"Disabled in config: {reason}",
                time.time() - start_time
            )
        
        # EXISTING CODE CONTINUES BELOW
        # Check if rule is excluded
        if self.is_rule_excluded(script_id):
            return self._create_result(
                script, "IGNORED",
                f"Excluded: {self.excluded_rules.get(script_id, 'No reason')}",
                time.time() - start_time
            )
        
        # ... rest of run_script method ...
```

**IN THE REMEDIATION BLOCK** (around line 640-700), update environment variable injection:

```python
            if mode == "remediate":
                # Add global remediation config
                env.update({
                    "BACKUP_ENABLED": str(...).lower(),
                    # ... existing code ...
                })
                
                # ... existing code for remediation_cfg ...
                
                # NEW: Inject variables from check_config
                if check_config:
                    if check_config.get("check_type") == "file_permission":
                        file_mode = check_config.get("file_mode")
                        file_owner = check_config.get("file_owner")
                        file_group = check_config.get("file_group")
                        file_path = check_config.get("file_path")
                        
                        if file_mode:
                            env["FILE_MODE"] = str(file_mode)
                        if file_owner:
                            env["FILE_OWNER"] = str(file_owner)
                        if file_group:
                            env["FILE_GROUP"] = str(file_group)
                        if file_path:
                            env["FILE_PATH"] = str(file_path)
                        
                        if self.verbose >= 2:
                            print(f"{Colors.BLUE}[DEBUG] Injected file check vars for {script_id}:{Colors.ENDC}")
                            print(f"{Colors.BLUE}      FILE_PATH={file_path}{Colors.ENDC}")
                            print(f"{Colors.BLUE}      FILE_MODE={file_mode}{Colors.ENDC}")
                            print(f"{Colors.BLUE}      FILE_OWNER={file_owner}:{file_group}{Colors.ENDC}")
                    
                    if check_config.get("check_type") == "flag_check":
                        flag_name = check_config.get("flag_name")
                        expected_value = check_config.get("expected_value")
                        
                        if flag_name:
                            env["FLAG_NAME"] = str(flag_name)
                        if expected_value:
                            env["EXPECTED_VALUE"] = str(expected_value)
                        
                        if self.verbose >= 2:
                            print(f"{Colors.BLUE}[DEBUG] Injected flag check vars for {script_id}:{Colors.ENDC}")
                            print(f"{Colors.BLUE}      FLAG_NAME={flag_name}{Colors.ENDC}")
                            print(f"{Colors.BLUE}      EXPECTED_VALUE={expected_value}{Colors.ENDC}")
                
                # Continue with existing code...
```

### 3. Update Your Bash Scripts

Modify file permission scripts to use environment variables:

**Before**:
```bash
#!/bin/bash
chmod 600 /etc/kubernetes/manifests/kube-apiserver.yaml
chown root:root /etc/kubernetes/manifests/kube-apiserver.yaml
```

**After**:
```bash
#!/bin/bash
# Use environment variables injected by Python
echo "[INFO] Applying file permissions to ${FILE_PATH}"

chmod "${FILE_MODE}" "${FILE_PATH}" || exit 1
chown "${FILE_OWNER}:${FILE_GROUP}" "${FILE_PATH}" || exit 1

echo "[PASS] File permissions applied"
exit 0
```

---

## What This Achieves

✅ **Check 5.3.2 is disabled** - Skipped automatically without running  
✅ **File paths are externalized** - Change in JSON, not in code  
✅ **Permissions are configurable** - Set in JSON, not in scripts  
✅ **No hardcoding** - All parameters from configuration  
✅ **Easy to audit** - Configuration is self-documenting  

---

## Testing

### Test 1: Verify config is loaded

```bash
cd /home/first/Project/cis-k8s-hardening
python3 -c "
import json
with open('cis_config.json') as f:
    config = json.load(f)
    print('✓ Config loaded successfully')
    print(f'✓ Found {len(config.get(\"checks_config\", {}))} checks in checks_config')
"
```

### Test 2: Check 5.3.2 is skipped

```bash
python3 cis_k8s_unified.py -vv 2>&1 | grep -A 2 "5.3.2"
# Should see: [SKIP] 5.3.2: Disabled for Safety First strategy
```

### Test 3: Verify environment variables are injected

```bash
python3 cis_k8s_unified.py -vvv 2>&1 | grep -E "FILE_MODE|FILE_OWNER|FILE_PATH"
# Should see: FILE_PATH=..., FILE_MODE=600, FILE_OWNER=root
```

---

## File Reference

| File | Purpose |
|------|---------|
| `cis_config_comprehensive.json` | Complete configuration example |
| `CONFIG_INTEGRATION_SNIPPET.py` | Python code snippets to integrate |
| `CIS_CONFIG_EXTERNALIZATION.md` | Complete reference guide |
| `CIS_CONFIG_QUICK_IMPLEMENTATION.md` | This file (quick start) |

---

## Troubleshooting

### Problem: "Check disabled in configuration" but want it enabled

**Solution**: Update `cis_config.json`:
```json
{
  "checks_config": {
    "5.3.2": {
      "enabled": true  // Change from false to true
    }
  }
}
```

### Problem: Environment variables not passed to Bash script

**Solution**: Check your `cis_k8s_unified.py` has this code in `run_script()`:
```python
if check_config.get("check_type") == "file_permission":
    env["FILE_MODE"] = str(file_mode)
    # ... etc
```

### Problem: Bash script says "FILE_PATH not found"

**Solution**: Your config might be missing the key. Check `cis_config.json`:
```json
{
  "checks_config": {
    "1.1.1": {
      "file_path": "/etc/kubernetes/manifests/kube-apiserver.yaml"  // Must be here
    }
  }
}
```

---

## Next Steps

1. ✅ Copy `cis_config_comprehensive.json` → `cis_config.json`
2. ✅ Update `cis_k8s_unified.py` with the code changes above
3. ✅ Update Bash scripts to use environment variables
4. ✅ Test with `python3 cis_k8s_unified.py -vv`
5. ✅ Verify 5.3.2 is skipped
6. ✅ Run full suite: `python3 cis_k8s_unified.py`

---

## Support

For detailed information, see:
- `CIS_CONFIG_EXTERNALIZATION.md` - Complete reference
- `CONFIG_INTEGRATION_SNIPPET.py` - Full code examples
- `cis_config_comprehensive.json` - Configuration examples
