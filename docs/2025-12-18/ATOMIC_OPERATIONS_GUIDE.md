# Atomic Operations & Health-Gated Rollback Guide

## Overview

This guide documents the robust file modification logic implemented in `cis_k8s_unified.py` to prevent corruption and boot loops when modifying critical Kubernetes manifest files.

## Problem Statement

**Previous Issues:**
1. Modifying `kube-apiserver.yaml` sometimes leaves the cluster in a broken state
2. Scripts proceed to the next check even if the API server is down, causing hangs
3. Half-written files could be read by the Kubelet, causing corruption

## Solution: Atomic Operations with Health Gating

### Two New Methods Implemented

#### 1. `update_manifest_safely(filepath, key, value)` - Atomic Copy-Paste Modifier

**Purpose:** Safely modify YAML manifests without corrupting the file

**Algorithm:**

```
STEP 1: Read original file content into memory
STEP 2: Parse YAML structure (preserving formatting and indentation)
STEP 3: Locate command list in spec.containers[0].command
STEP 4: Search for key or append if missing
STEP 5: Write FULL content to temporary file
STEP 6: Use os.replace(temp_file, filepath) - ATOMIC!
STEP 7: Verify new file integrity
```

**Key Features:**
- ✅ Preserves indentation and comments
- ✅ Atomic overwrite prevents Kubelet from seeing half-written files
- ✅ Automatic backup creation before modification
- ✅ Handles both key modification and append operations
- ✅ Comprehensive error handling with rollback

**Return Value:**
```python
{
    'success': bool,           # True if modification succeeded
    'original_path': str,      # Path to modified file
    'backup_path': str,        # Path to backup file
    'message': str,            # Status message
    'changes_made': int        # Number of modifications
}
```

**Usage Example:**
```python
# Modify API server audit policy setting
result = runner.update_manifest_safely(
    filepath="/etc/kubernetes/manifests/kube-apiserver.yaml",
    key="--audit-policy-file=",
    value="/etc/kubernetes/audit-policy.yaml"
)

if result['success']:
    print(f"Modified successfully. Backup: {result['backup_path']}")
else:
    print(f"Modification failed: {result['message']}")
```

#### 2. `apply_remediation_with_health_gate()` - Health-Gated Rollback

**Purpose:** Apply remediation with automatic health checking and rollback

**Flow Diagram:**

```
┌─────────────────────────────────────────────────────────────┐
│ STEP 1: BACKUP                                              │
│ Create backup: filepath.bak_{timestamp}                    │
│ Return False if fails                                       │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ STEP 2: APPLY                                               │
│ Call update_manifest_safely()                               │
│ Atomic modification with temporary file                     │
│ Return False if fails                                       │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ STEP 3: HEALTH GATE                                         │
│ Loop check https://127.0.0.1:6443/healthz (60s timeout)    │
│                                                             │
│ ┌─────────────────┐  ┌──────────────────┐                  │
│ │ UNHEALTHY?      │  │ HEALTHY?         │                  │
│ │ Timeout reached │  │ API responds "ok"│                  │
│ └────────┬────────┘  └────────┬─────────┘                  │
│          │                    │                             │
│          ▼                    ▼                             │
│   ROLLBACK & FAIL    CONTINUE TO AUDIT                      │
└─────────────────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ STEP 4: AUDIT VERIFICATION                                  │
│ Run corresponding audit script                              │
│                                                             │
│ ┌──────────────────┐  ┌──────────────────┐                 │
│ │ AUDIT PASS       │  │ AUDIT FAIL       │                 │
│ │ Config valid     │  │ Config invalid   │                 │
│ └────────┬─────────┘  └────────┬─────────┘                 │
│          │                    │                             │
│          ▼                    ▼                             │
│    SUCCESS (FIXED)   ROLLBACK & FAIL                        │
└─────────────────────────────────────────────────────────────┘
```

**Arguments:**
```python
filepath: str          # Path to manifest (e.g., /etc/kubernetes/manifests/kube-apiserver.yaml)
key: str              # Key to modify (e.g., "--audit-policy-file=")
value: str            # New value (e.g., "/etc/kubernetes/audit-policy.yaml")
check_id: str         # CIS check ID for logging (e.g., "1.2.5")
script_dict: dict     # Script metadata containing 'path' to audit script
timeout: int          # Seconds to wait for API health (default: 60)
```

**Return Value:**
```python
{
    'success': bool,              # True if remediation succeeded completely
    'status': str,                # One of:
                                 #   'FIXED' - success
                                 #   'REMEDIATION_FAILED' - modification or health failed
                                 #   'REMEDIATION_FAILED_ROLLED_BACK' - failed but recovered
                                 #   'REMEDIATION_FAILED_ROLLBACK_FAILED' - CRITICAL
    'reason': str,                # Human-readable explanation
    'backup_path': str,           # Path to backup file
    'audit_verified': bool        # True if audit check passed
}
```

**Usage Example:**
```python
# Apply remediation with full health gating and audit verification
result = runner.apply_remediation_with_health_gate(
    filepath="/etc/kubernetes/manifests/kube-apiserver.yaml",
    key="--audit-policy-file=",
    value="/etc/kubernetes/audit-policy.yaml",
    check_id="1.2.5",
    script_dict={"path": "/path/to/1.2.5_remediate.sh"},
    timeout=60
)

if result['success']:
    print(f"✓ Remediation verified: {result['reason']}")
    if result['audit_verified']:
        print("  Audit check PASSED")
else:
    print(f"✗ Remediation failed: {result['reason']}")
    if result['backup_path']:
        print(f"  Manual recovery: sudo cp {result['backup_path']} {filepath}")
```

## Integration with Existing Flow

### Current Safety-First Remediation Flow

The `run_script()` method already implements a 4-step verification:

```python
if mode == "remediate" and status == "FIXED":
    # STEP 1: Capture backup path
    backup_file = self._get_backup_file_path(script_id, env)
    
    # STEP 2: Health Check Barrier
    api_health_ok = self._wait_for_api_healthy(script_id, timeout=60)
    
    if not api_health_ok:
        # TRIGGER ROLLBACK
        self._rollback_manifest(script_id, backup_file)
    else:
        # STEP 3: Audit verification
        # STEP 4: Decision based on audit result
```

### How to Use Atomic Operations

**Option 1: Use the Full Health-Gated Flow**
```python
# Instead of running bash scripts manually, use:
result = runner.apply_remediation_with_health_gate(
    filepath="/etc/kubernetes/manifests/kube-apiserver.yaml",
    key="--audit-policy-file=",
    value="/etc/kubernetes/audit-policy.yaml",
    check_id="1.2.5",
    script_dict=script
)

if result['success']:
    status = "FIXED"
    reason = result['reason']
else:
    status = "REMEDIATION_FAILED"
    reason = result['reason']
```

**Option 2: Use Just the Atomic Modifier**
```python
# For cases where you want direct control
update_result = runner.update_manifest_safely(
    filepath="/etc/kubernetes/manifests/kube-apiserver.yaml",
    key="--audit-policy-file=",
    value="/etc/kubernetes/audit-policy.yaml"
)

if update_result['success']:
    # Manually handle health checking
    # (already done by existing remediation flow)
    pass
```

**Option 3: Hybrid Approach**
```python
# Use existing bash scripts but add atomic operations
# when modifying critical files:

# Before modifying:
backup = runner.update_manifest_safely(...).get('backup_path')

# Run remediation script
# (if it fails, you have the backup)

# Health check is already in run_script()
```

## Rollback Scenarios

### Scenario 1: Modification Fails
```
Backup created: /etc/kubernetes/manifests/kube-apiserver.yaml.bak_20251218_123456
Modification failed: [ERROR] Temp file write failed

→ Backup remains intact, original file untouched
```

### Scenario 2: Health Check Fails
```
Backup created: kube-apiserver.yaml.bak_20251218_123456
Modification applied atomically ✓
Health check timeout (60s) ✗

→ Automatic rollback triggered
→ Backup restored to original path
→ Cluster recovers
→ User informed: ROLLBACK_SUCCEEDED
```

### Scenario 3: Audit Verification Fails
```
Backup created ✓
Modification applied ✓
API Server healthy ✓
Audit check fails (invalid config) ✗

→ Automatic rollback triggered
→ Backup restored
→ Cluster recovers
→ User informed: Config was invalid
```

### Scenario 4: CRITICAL - Rollback Fails
```
Backup created ✓
Modification applied ✓
API Server unhealthy ✗
Rollback attempt failed ✗

→ EMERGENCY_STOP
→ User must intervene manually

Manual recovery:
  sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml.bak_* \
       /etc/kubernetes/manifests/kube-apiserver.yaml
  sudo systemctl restart kubelet
  kubectl get nodes  # Verify
```

## Configuration & Logging

### Verbose Output Levels

```python
# Initialize with verbosity
runner = CISUnifiedRunner(verbose=0)  # Minimal output
runner = CISUnifiedRunner(verbose=1)  # Standard (recommended)
runner = CISUnifiedRunner(verbose=2)  # Full debug output
```

**Verbose Output Examples:**
```
# verbose >= 1:
[*] Modified line 42: --audit-policy-file=/etc/kubernetes/audit-policy.yaml
[✓] Backup created: /etc/kubernetes/manifests/kube-apiserver.yaml.bak_20251218_123456
[✓] API Server healthy after 8.3s

# verbose >= 2:
[DEBUG] Read manifest: /etc/kubernetes/manifests/kube-apiserver.yaml (124 lines)
[DEBUG] Found command section at line 18, indent=12
[DEBUG] Wrote temporary file: /etc/kubernetes/manifests/kube-apiserver.yaml.tmp_20251218_123456
[DEBUG] API check attempt 3/30: Connection timeout
```

### Activity Logging

All operations are logged to `cis_runner.log`:

```
[2025-12-18 14:23:45] MANIFEST_UPDATE_SUCCESS: /etc/kubernetes/manifests/kube-apiserver.yaml: 1 change(s), backup: ...
[2025-12-18 14:23:50] API_HEALTH_OK: 1.2.5: 5.2s
[2025-12-18 14:23:52] REMEDIATION_SUCCESS_VERIFIED: 1.2.5
```

## Best Practices

### 1. Always Use Health Gating for API Server Changes
```python
# ✓ GOOD
result = runner.apply_remediation_with_health_gate(...)

# ✗ BAD - no health check
runner.update_manifest_safely(...)
```

### 2. Test on Non-Critical Clusters First
```
1. Test on dev/staging cluster
2. Verify audit checks pass
3. Check cluster stability (5+ minutes)
4. Deploy to production
```

### 3. Keep Backups
```bash
# Backups are automatically created as:
# /etc/kubernetes/manifests/kube-apiserver.yaml.bak_YYYYMMDD_HHMMSS

# Archive them:
tar czf kube-apiserver-backups-$(date +%Y%m%d).tar.gz \
        /etc/kubernetes/manifests/kube-apiserver.yaml.bak_*
```

### 4. Monitor Logs
```bash
# Watch remediation logs in real-time
tail -f cis_runner.log | grep -E "REMEDIATION|HEALTH|ROLLBACK"

# Check for errors
grep "ERROR\|CRITICAL\|FAILED" cis_runner.log
```

### 5. Manual Recovery Procedure
```bash
# If something goes wrong:

# 1. Check cluster health
kubectl get nodes
kubectl get pods -n kube-system | grep api

# 2. Find the latest backup
ls -lt /etc/kubernetes/manifests/kube-apiserver.yaml.bak_*

# 3. Restore
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml.bak_LATEST \
        /etc/kubernetes/manifests/kube-apiserver.yaml

# 4. Restart Kubelet
sudo systemctl restart kubelet

# 5. Verify
kubectl get nodes
```

## API Reference

### `update_manifest_safely(filepath, key, value)`

**Parameters:**
- `filepath` (str): Absolute path to YAML manifest
- `key` (str): Key to modify or append (e.g., `--audit-policy-file=`)
- `value` (str): Value for the key

**Returns:** dict with keys: `success`, `original_path`, `backup_path`, `message`, `changes_made`

**Raises:** None (all errors caught and returned in result dict)

**Thread-safe:** Yes
**Atomic:** Yes (uses `os.replace()`)
**Backup:** Automatic

---

### `apply_remediation_with_health_gate(filepath, key, value, check_id, script_dict, timeout=60)`

**Parameters:**
- `filepath` (str): Absolute path to YAML manifest
- `key` (str): Key to modify (e.g., `--audit-policy-file=`)
- `value` (str): Value for the key
- `check_id` (str): CIS check ID for logging
- `script_dict` (dict): Script metadata with 'path' key
- `timeout` (int): Health check timeout in seconds (default: 60)

**Returns:** dict with keys: `success`, `status`, `reason`, `backup_path`, `audit_verified`

**Raises:** None (all errors caught and returned in result dict)

**Thread-safe:** Yes
**Blocking:** Yes (waits for API health and audit)
**Recovery:** Automatic rollback on health/audit failure

---

### `_wait_for_api_healthy(check_id, timeout=60)`

**Parameters:**
- `check_id` (str): Check ID for logging
- `timeout` (int): Timeout in seconds

**Returns:** bool (True if API became healthy)

**Checks:** `https://127.0.0.1:6443/healthz` endpoint
**Interval:** 2 seconds between checks
**Insecure SSL:** Yes (uses `-k` flag with curl)

---

### `_rollback_manifest(check_id, backup_file)`

**Parameters:**
- `check_id` (str): Check ID for logging
- `backup_file` (str): Path to backup file

**Returns:** bool (True if rollback succeeded)

**Preserves:** Broken config as `.broken_YYYYMMDD_HHMMSS`
**Waits:** 2 seconds after rollback for manifest reload

## Troubleshooting

### "Manifest file not found"
```
Cause: Wrong filepath
Solution: Verify path with: ls -la /etc/kubernetes/manifests/
```

### "Cannot read manifest file: Permission denied"
```
Cause: Running without root privileges
Solution: Run with sudo:
  sudo python3 cis_k8s_unified.py
```

### "API Server failed to restart within 60s"
```
Cause: Configuration invalid or cluster issues
Solution: Check logs:
  journalctl -u kubelet -n 50
  kubectl describe pod kube-apiserver -n kube-system
  Manual rollback using procedures above
```

### "Audit verification failed"
```
Cause: Configuration doesn't satisfy CIS requirement
Solution: Review audit output:
  bash /path/to/check_audit.sh
  Compare with previous version
  Adjust configuration and retest
```

## Testing the Implementation

### Unit Test Example
```python
# Create test script
cat > test_atomic_ops.py << 'EOF'
#!/usr/bin/env python3
import os
import shutil
import tempfile
from cis_k8s_unified import CISUnifiedRunner

# Create test runner
runner = CISUnifiedRunner(verbose=2)

# Create test manifest
with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
    test_file = f.name
    f.write("""
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: test
    image: test:latest
    command:
    - --flag1=value1
    - --flag2=value2
""")

try:
    # Test atomic modification
    result = runner.update_manifest_safely(
        test_file,
        "--flag1=",
        "new-value"
    )
    
    print(f"Test result: {result['success']}")
    print(f"Changes: {result['changes_made']}")
    print(f"Backup: {result['backup_path']}")
    
    # Verify file was modified
    with open(test_file, 'r') as f:
        content = f.read()
        assert 'new-value' in content
        print("✓ File modification verified")
    
finally:
    os.unlink(test_file)
    if result['backup_path'] and os.path.exists(result['backup_path']):
        os.unlink(result['backup_path'])
EOF

python3 test_atomic_ops.py
```

## Summary

The atomic operations implementation provides:

✅ **Safety**: No corrupted half-written files
✅ **Atomicity**: Uses `os.replace()` for kernel-level guarantee
✅ **Reversibility**: Automatic backups and rollback
✅ **Verification**: Health checks and audit confirmation
✅ **Reliability**: Comprehensive error handling
✅ **Logging**: Full activity trail for auditing

Use these functions whenever modifying critical Kubernetes manifests in the CIS hardening process.
