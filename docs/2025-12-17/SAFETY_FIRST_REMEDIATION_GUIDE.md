# Safety-First Remediation Flow - Complete Implementation Guide

## Overview

The Safety-First Remediation Flow is a comprehensive system to prevent cluster hangs and infinite loops during remediation. It implements **automatic backup, health verification, and intelligent rollback** to ensure cluster stability.

---

## Architecture

### 4-Step Verification Process

```
┌─────────────────────────────────────────┐
│ Remediation Script Executes             │
│ (Modifies manifest or config)           │
└────────────────┬────────────────────────┘
                 │
                 ▼
        ┌─────────────────┐
        │ Script Returns  │
        │ Status = FIXED? │
        └────────┬────────┘
                 │
        No       │ Yes
        ──►PASS  │
                 ▼
     ┌──────────────────────────────┐
     │STEP 1: Capture Backup Path   │
     │  - From env var BACKUP_FILE  │
     │  - From standard path        │
     └──────────────┬───────────────┘
                    │
                    ▼
     ┌──────────────────────────────┐
     │STEP 2: Health Check (60s)    │
     │ Check API port 6443/healthz  │
     └──────────┬───────────────────┘
                │
        Healthy │ Unhealthy
           ┌────┴────┐
           │         ▼
           │    ┌─────────────┐
           │    │  ROLLBACK   │
           │    │ + MARK FAIL │
           │    └─────────────┘
           │
           ▼
     ┌──────────────────────────┐
     │STEP 3: Run Audit Script  │
     │ Verify remediation works │
     └──────────┬───────────────┘
                │
          Pass  │  Fail
        ┌───────┴───────┐
        │               ▼
        │          ┌─────────────┐
        │          │  ROLLBACK   │
        │          │ + MARK FAIL │
        │          └─────────────┘
        │
        ▼
   ┌──────────┐
   │ SUCCESS  │
   │ FIXED ✓  │
   └──────────┘
```

---

## Implementation Details

### 1. Capture Backup Path: `_get_backup_file_path()`

**Purpose:** Identify where the remediation script stored the backup of the original manifest.

**Priority Logic:**
```python
PRIORITY 1: Check environment variable BACKUP_FILE
  - Remediation scripts export BACKUP_FILE=/path/to/backup.bak
  - Most reliable: script controls exact location
  
PRIORITY 2: Search standard backup directory
  - Look in /var/backups/cis-remediation/{check_id}_*.bak
  - Find most recent if multiple backups exist
```

**Signature:**
```python
def _get_backup_file_path(self, check_id, env):
    """Returns: str (path to backup) or None"""
```

**Example Flow:**
```python
# For check 1.2.5 (API Server)
backup_file = self._get_backup_file_path("1.2.5", env)
# Returns: "/var/backups/cis-remediation/1.2.5_20251217_143022.bak"
```

---

### 2. Health Check Barrier: `_wait_for_api_healthy()`

**Purpose:** Verify the API Server port is responding to requests after remediation.

**Health Check Method:**
```bash
curl -s -k -m 5 https://127.0.0.1:6443/healthz
```

**Parameters:**
- `-s`: Silent mode (no progress)
- `-k`: Insecure (ignore TLS cert errors)
- `-m 5`: 5 second timeout per attempt
- Endpoint: `/healthz` returns "ok" if healthy

**Logic:**
```
while elapsed_time < 60 seconds:
    try curl to /healthz
    if response == "ok":
        return True
    wait 2 seconds
    retry

if no success after 60s:
    return False (API is dead)
```

**Behavior:**
- ✅ **Healthy API:** Continue to Step 3 (Audit Verification)
- ❌ **Unhealthy API:** TRIGGER ROLLBACK (remediation broke something critical)

**Signature:**
```python
def _wait_for_api_healthy(self, check_id, timeout=60):
    """Returns: bool (True = healthy, False = timeout)"""
```

---

### 3. Audit Verification: Run Corresponding Audit Script

**Purpose:** Double-check that remediation actually fixed the issue.

**Logic:**
```python
if api_is_healthy:
    run_audit_script(corresponding_audit)
    
    if audit_status == "PASS":
        return SUCCESS (status = FIXED)
    else:
        return FAILURE (trigger rollback)
```

**Why This Step?**
- Remediation script can return 0 (success) but make wrong changes
- Example: Modifies config file but syntax is invalid internally
- Audit script independently verifies compliance

---

### 4. Intelligent Rollback: `_rollback_manifest()`

**Purpose:** Restore original manifest from backup when things go wrong.

**Rollback Path Mapping:**
```python
check_id    | component              | manifest_path
──────────────────────────────────────────────────────
1.2.x       | API Server             | /etc/kubernetes/manifests/kube-apiserver.yaml
2.x         | etcd                   | /etc/kubernetes/manifests/etcd.yaml
4.x         | Kubelet                | /var/lib/kubelet/config.yaml
```

**Rollback Sequence:**
```
1. Check backup exists
2. Determine original manifest path
3. Save broken config (for debugging)
   └─ /path/to/manifest.yaml.broken_YYYYMMDD_HHMMSS
4. Restore from backup
5. Wait for kubelet to reload manifest (2 sec)
```

**Error Handling:**
```
No Backup Found        → Fail + Log (cannot fix without backup)
File Not Found         → Fail + Log
Permission Denied      → Fail + Log (requires sudo/root)
Other Exception        → Fail + Log
```

**Signature:**
```python
def _rollback_manifest(self, check_id, backup_file):
    """Returns: bool (True = rollback succeeded, False = failed)"""
```

---

## Execution Flow with Examples

### Scenario 1: Successful Remediation ✅

```
[*] Safety-First Remediation Verification for 1.2.5...

STEP 1: Capture Backup Path
    Found backup file: /var/backups/cis-remediation/1.2.5_20251217_143022.bak

STEP 2: Health Check Barrier
    [*] Waiting for API Server to become healthy (timeout: 60s)...
    [✓] API Server healthy after 3.2s

STEP 3: Run Audit
    [✓] API Server healthy. Running audit verification...
    Audit status: PASS

STEP 4: Success
    [✓] VERIFIED: API healthy and audit passed.
    Status: FIXED ✓
    Reason: [FIXED] Remediation verified (API + Audit).
```

---

### Scenario 2: API Server Crash → Automatic Rollback ❌

```
[*] Safety-First Remediation Verification for 1.2.5...

STEP 1: Capture Backup Path
    Found backup file: /var/backups/cis-remediation/1.2.5_20251217_143022.bak

STEP 2: Health Check Barrier
    [*] Waiting for API Server to become healthy (timeout: 60s)...
    [✗] CRITICAL: API Server failed to become healthy within 60s.
    [!] Attempting automatic rollback for 1.2.5...

ROLLBACK EXECUTED:
    [*] Rolling back: /etc/kubernetes/manifests/kube-apiserver.yaml
        From backup: /var/backups/cis-remediation/1.2.5_20251217_143022.bak
        Saved broken config: /etc/kubernetes/manifests/kube-apiserver.yaml.broken_20251217_143025
    [✓] Rollback completed successfully
    [✓] Rollback completed. Waiting for cluster recovery...

CLUSTER RECOVERY WAIT:
    [*] Master Node detected. 3-Step health verification (Timeout: 300s)...
    [✓] API Server healthy after 15.4s

STATUS:
    Status: REMEDIATION_FAILED ❌
    Reason: [REMEDIATION_FAILED] API Server failed to restart. Automatic rollback succeeded.

LOG ENTRY:
    [REMEDIATION_API_HEALTH_FAILED] 1.2.5: Rollback success
```

---

### Scenario 3: API Healthy but Audit Fails → Rollback ❌

```
[*] Safety-First Remediation Verification for 1.2.5...

STEP 1: Capture Backup Path
    Found backup file: /var/backups/cis-remediation/1.2.5_20251217_143022.bak

STEP 2: Health Check Barrier
    [*] Waiting for API Server to become healthy (timeout: 60s)...
    [✓] API Server healthy after 2.8s

STEP 3: Run Audit
    [✓] API Server healthy. Running audit verification...
    Audit status: FAIL
    Audit reason: No secure port flag found

ROLLBACK EXECUTED:
    [✗] AUDIT FAILED: API healthy but audit verification failed.
    [!] Attempting automatic rollback for 1.2.5...
    
    [*] Rolling back: /etc/kubernetes/manifests/kube-apiserver.yaml
        From backup: /var/backups/cis-remediation/1.2.5_20251217_143022.bak
    [✓] Rollback completed successfully
    [✓] Rollback completed. Waiting for cluster recovery...

STATUS:
    Status: REMEDIATION_FAILED ❌
    Reason: [REMEDIATION_FAILED] Audit verification failed: No secure port flag found. 
            Automatic rollback succeeded.

LOG ENTRY:
    [REMEDIATION_AUDIT_FAILED] 1.2.5: No secure port flag found, Rollback success
```

---

## Code Integration

### In `run_script()` Method

```python
def run_script(self, script, mode):
    # ... run remediation script ...
    
    # Parse output
    status, reason, fix_hint, cmds = self._parse_script_output(...)
    
    # ========== SAFETY-FIRST REMEDIATION FLOW (NEW) ==========
    if mode == "remediate" and status == "FIXED":
        
        # STEP 1: Capture Backup Path
        backup_file = self._get_backup_file_path(script_id, env)
        
        # STEP 2: Health Check Barrier
        api_health_ok = self._wait_for_api_healthy(script_id, timeout=60)
        
        if not api_health_ok:
            # API failed → ROLLBACK
            rollback_success = self._rollback_manifest(script_id, backup_file)
            status = "REMEDIATION_FAILED"
            reason = f"API Server failed. Rollback {'succeeded' if rollback_success else 'FAILED'}."
        
        else:
            # API healthy → Run audit
            audit_result = subprocess.run([audit_script])
            audit_status = parse_output(audit_result)
            
            if audit_status == "PASS":
                # ✅ SUCCESS
                reason = "[FIXED] Remediation verified (API + Audit)."
            else:
                # ❌ FAILURE → ROLLBACK
                rollback_success = self._rollback_manifest(script_id, backup_file)
                status = "REMEDIATION_FAILED"
                reason = f"Audit failed. Rollback {'succeeded' if rollback_success else 'FAILED'}."
    
    return result_dict
```

---

## Helper Methods Reference

### 1. `_get_backup_file_path(check_id, env)`

**Returns:**
- `str`: Path to backup file (if found)
- `None`: No backup found

**Raises:** None (returns None on failure)

**Side Effects:**
- Prints debug info to stdout
- Logs activity to file

---

### 2. `_wait_for_api_healthy(check_id, timeout=60)`

**Returns:**
- `bool`: True if API became healthy
- `bool`: False if timeout reached

**Raises:** None (catches all exceptions)

**Side Effects:**
- Makes network requests (curl)
- Prints progress to stdout
- Logs activity

---

### 3. `_rollback_manifest(check_id, backup_file)`

**Returns:**
- `bool`: True if rollback succeeded
- `bool`: False if rollback failed

**Raises:** None (catches all exceptions)

**Side Effects:**
- Modifies filesystem (copies files)
- Preserves broken config for debugging
- Logs activity

---

## Configuration

### Environment Variables

Remediation scripts should export:

```bash
#!/bin/bash

# Tell verification where backup is located
export BACKUP_FILE="/var/backups/cis-remediation/1.2.5_${TIMESTAMP}.bak"

# Or use standard directory
export BACKUP_DIR="/var/backups/cis-remediation"

# Example: Create backup
mkdir -p "$BACKUP_DIR"
cp /etc/kubernetes/manifests/kube-apiserver.yaml \
   "${BACKUP_DIR}/1.2.5_$(date +%s).bak"

# Now make changes
sed -i 's/--secure-port=.*/--secure-port=6443/' \
   /etc/kubernetes/manifests/kube-apiserver.yaml

exit $?
```

### Config File Settings

If using `cis_config.json`:

```json
{
  "remediation": {
    "global": {
      "backup_enabled": true,
      "backup_dir": "/var/backups/cis-remediation",
      "dry_run": false,
      "wait_for_api": true
    }
  }
}
```

---

## Benefits

| Feature | Benefit |
|---------|---------|
| **Health Check Barrier** | Prevents cascading failures when API server crashes |
| **Audit Verification** | Catches invalid config changes that return 0 but don't work |
| **Automatic Rollback** | Recovers broken manifests without manual intervention |
| **Broken Config Backup** | Preserves failed state for debugging (`.broken_TIMESTAMP`) |
| **Activity Logging** | Maintains audit trail of all rollbacks and failures |

---

## Troubleshooting

### Rollback Says "Backup Not Found"

**Problem:** `[✗] Backup file not found: None`

**Solution:**
1. Ensure remediation script exports `BACKUP_FILE` env var
2. Verify backup directory exists: `/var/backups/cis-remediation/`
3. Check remediation script creates backup before modifying

```bash
# In remediation script:
export BACKUP_FILE="/var/backups/cis-remediation/1.2.5_$(date +%s).bak"
cp /etc/kubernetes/manifests/kube-apiserver.yaml "$BACKUP_FILE"
```

### API Health Check Timeout

**Problem:** `[✗] API Server did not become healthy within 60s`

**Possible Causes:**
1. Invalid manifest syntax
2. Missing required flags
3. Port conflict
4. Certificate issues

**Debug:**
```bash
# Check API server logs
journalctl -u kubelet -n 50 | grep apiserver

# Check port
netstat -tlnp | grep 6443

# Check manifest syntax
kubectl apply -f /etc/kubernetes/manifests/kube-apiserver.yaml --dry-run

# Manual rollback
cp /var/backups/cis-remediation/1.2.5_*.bak /etc/kubernetes/manifests/kube-apiserver.yaml
```

### Rollback Failed - Permission Denied

**Problem:** `[✗] Rollback failed - permission denied`

**Solution:**
- Run script as root: `sudo python3 cis_k8s_unified.py`
- Or use: `sudo -E python3 cis_k8s_unified.py` (preserve env)

---

## Testing

### Test Case 1: Successful Remediation

```bash
# Run remediation for a simple check (e.g., 1.1.1)
python3 cis_k8s_unified.py
# Select: 2 (Remediation only)
# Select: 1 (Level 1)
# Verify: Status shows FIXED ✓
```

### Test Case 2: Verify Rollback Works

```bash
# Modify a remediation script to introduce a syntax error
vim Level_1_Master_Node/1.2.5_remediate.sh
# Add invalid YAML to manifest
# Save and run: Status should show REMEDIATION_FAILED
# Check: Original manifest restored
cat /etc/kubernetes/manifests/kube-apiserver.yaml  # Should be original
```

### Test Case 3: Check Broken Config Saved

```bash
# After a rollback with failures
ls -la /etc/kubernetes/manifests/*.broken_*
# Should show saved broken states for debugging
```

---

## Performance Impact

- **Health Check:** 2-5 seconds (typically)
- **Audit Verification:** Script timeout (default 60s)
- **Rollback:** <1 second
- **Total Overhead:** 4-10 seconds per remediation

**Optimization:** Use `--fix-failed-only` to skip already-passing checks.

---

## Summary

The Safety-First Remediation Flow provides:
1. ✅ Automatic backup capture
2. ✅ Health check barrier to detect failures
3. ✅ Audit verification to catch invalid configs
4. ✅ Intelligent rollback to restore working state
5. ✅ Comprehensive logging for audit trail
6. ✅ No manual intervention required (unless backup is missing)

This prevents infinite remediation loops and cluster hangs while maintaining full CIS compliance.
