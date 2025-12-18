# Safety-First Remediation - Implementation Quick Reference

## Complete `run_script()` Implementation Highlights

### New Code Section (Lines 883-948)

```python
# ========== SAFETY-FIRST REMEDIATION FLOW (NEW) ==========
# For remediation mode: Implement 4-step Safety-First verification with automatic rollback
if mode == "remediate" and status == "FIXED":
    print(f"\n{Colors.YELLOW}[*] Safety-First Remediation Verification for {script_id}...{Colors.ENDC}")
    
    # STEP 1: Capture backup path from script environment or standard location
    backup_file = self._get_backup_file_path(script_id, env)
    
    # STEP 2: Health Check Barrier (CRITICAL)
    # Check if API Server becomes healthy after remediation
    api_health_ok = self._wait_for_api_healthy(script_id, timeout=60)
    
    if not api_health_ok:
        # API Server failed to restart - TRIGGER ROLLBACK
        print(f"{Colors.RED}[✗] CRITICAL: API Server failed to become healthy within 60s.{Colors.ENDC}")
        print(f"{Colors.RED}[!] Attempting automatic rollback for {script_id}...{Colors.ENDC}")
        
        rollback_success = self._rollback_manifest(script_id, backup_file)
        
        if rollback_success:
            print(f"{Colors.YELLOW}[✓] Rollback completed. Waiting for cluster recovery...{Colors.ENDC}")
            # Wait for cluster to recover after rollback
            time.sleep(5)
            self.wait_for_healthy_cluster(skip_health_check=False)
        
        status = "REMEDIATION_FAILED"
        reason = f"[REMEDIATION_FAILED] API Server failed to restart. Automatic rollback {'succeeded' if rollback_success else 'FAILED - MANUAL INTERVENTION REQUIRED'}."
        self.log_activity("REMEDIATION_API_HEALTH_FAILED", f"{script_id}: Rollback {'success' if rollback_success else 'FAILED'}")
    
    else:
        # STEP 3: API is healthy - Run audit verification
        print(f"{Colors.GREEN}[✓] API Server healthy. Running audit verification...{Colors.ENDC}")
        
        audit_script_path = script["path"].replace("_remediate.sh", "_audit.sh")
        
        if os.path.exists(audit_script_path):
            try:
                # Wait briefly for config changes to propagate
                time.sleep(2)
                
                # Run audit script to verify
                audit_result = subprocess.run(
                    ["bash", audit_script_path],
                    capture_output=True,
                    text=True,
                    timeout=self.script_timeout,
                    env=env
                )
                
                # Parse audit output
                audit_status, audit_reason, _, _ = self._parse_script_output(
                    audit_result, script_id, "audit", is_manual
                )
                
                # STEP 4: Decision based on audit result
                if audit_status == "PASS":
                    # ✅ SUCCESS: Audit passed
                    print(f"{Colors.GREEN}[✓] VERIFIED: API healthy and audit passed.{Colors.ENDC}")
                    reason = f"[FIXED] Remediation verified (API + Audit). {reason}"
                    # Status remains FIXED
                else:
                    # ❌ FAILURE: Audit failed despite healthy API
                    print(f"{Colors.RED}[✗] AUDIT FAILED: API healthy but audit verification failed.{Colors.ENDC}")
                    print(f"{Colors.RED}[!] Attempting automatic rollback for {script_id}...{Colors.ENDC}")
                    
                    rollback_success = self._rollback_manifest(script_id, backup_file)
                    
                    if rollback_success:
                        print(f"{Colors.YELLOW}[✓] Rollback completed. Waiting for cluster recovery...{Colors.ENDC}")
                        time.sleep(5)
                        self.wait_for_healthy_cluster(skip_health_check=False)
                    
                    status = "REMEDIATION_FAILED"
                    reason = (
                        f"[REMEDIATION_FAILED] Audit verification failed: {audit_reason}. "
                        f"Automatic rollback {'succeeded' if rollback_success else 'FAILED - MANUAL INTERVENTION REQUIRED'}."
                    )
                    self.log_activity(
                        "REMEDIATION_AUDIT_FAILED",
                        f"{script_id}: {audit_reason}, Rollback {'success' if rollback_success else 'FAILED'}"
                    )
            
            except subprocess.TimeoutExpired:
                print(f"{Colors.YELLOW}[!] Audit verification timeout for {script_id}{Colors.ENDC}")
                status = "REMEDIATION_FAILED"
                reason = "[REMEDIATION_FAILED] Audit verification timed out"
                self.log_activity("REMEDIATION_VERIFICATION_TIMEOUT", script_id)
            
            except Exception as e:
                print(f"{Colors.YELLOW}[!] Audit verification error for {script_id}: {str(e)}{Colors.ENDC}")
                status = "REMEDIATION_FAILED"
                reason = f"[REMEDIATION_FAILED] Audit verification error: {str(e)}"
                self.log_activity("REMEDIATION_VERIFICATION_ERROR", f"{script_id}: {str(e)}")
        else:
            # Audit script doesn't exist
            print(f"{Colors.YELLOW}[!] Audit script not found for verification: {audit_script_path}{Colors.ENDC}")
            status = "REMEDIATION_FAILED"
            reason = "[REMEDIATION_FAILED] Cannot verify - audit script not found"
            self.log_activity("REMEDIATION_AUDIT_NOT_FOUND", f"{script_id}: {audit_script_path}")
```

---

## Three New Helper Methods

### 1. `_get_backup_file_path(check_id, env)` - Lines 1024-1056

**Purpose:** Locate backup file from environment or standard location

**Returns:**
- `str`: Path to backup file if found
- `None`: If no backup exists

**Logic:**
```
PRIORITY 1: Check BACKUP_FILE environment variable
           (exported by remediation script)
           
PRIORITY 2: Search /var/backups/cis-remediation/
           for pattern {check_id}_*.bak
           
FALLBACK: Return None if nothing found
```

---

### 2. `_wait_for_api_healthy(check_id, timeout=60)` - Lines 1058-1106

**Purpose:** Verify API Server is responding to requests

**Returns:**
- `bool`: True if API healthy
- `bool`: False if timeout (60 seconds)

**Health Check Method:**
```bash
curl -s -k -m 5 https://127.0.0.1:6443/healthz
```

**Logic:**
```
for 60 seconds (every 2 seconds):
    try curl to healthz endpoint
    if response contains "ok":
        log success
        return True
    
if timeout reached:
    log failure
    return False
```

---

### 3. `_rollback_manifest(check_id, backup_file)` - Lines 1108-1177

**Purpose:** Restore manifest from backup after failed remediation

**Returns:**
- `bool`: True if rollback succeeded
- `bool`: False if rollback failed

**Path Mapping:**
```python
1.2.x  →  /etc/kubernetes/manifests/kube-apiserver.yaml
2.x    →  /etc/kubernetes/manifests/etcd.yaml
4.x    →  /var/lib/kubelet/config.yaml
```

**Rollback Sequence:**
```
1. Validate backup file exists
2. Determine original manifest path (from check_id)
3. Save current broken config as .broken_TIMESTAMP
4. Copy backup file to original location
5. Wait 2 seconds for kubelet to reload
6. Return success status
```

---

## Integration Points

### Where Safety-First is Invoked

In `run_script()` method:

```python
# Line 883: Check if remediation succeeded
if mode == "remediate" and status == "FIXED":
    # Execute Safety-First Remediation Flow
```

### Return Status Values

When Safety-First runs, status can be:

| Status | Meaning | Logged |
|--------|---------|--------|
| `FIXED` | Remediation successful (API + Audit passed) | `API_HEALTH_OK` |
| `REMEDIATION_FAILED` | API crashed | `REMEDIATION_API_HEALTH_FAILED` |
| `REMEDIATION_FAILED` | Audit failed | `REMEDIATION_AUDIT_FAILED` |
| `REMEDIATION_FAILED` | Rollback failed | `ROLLBACK_ERROR` |

### Activity Log Entries

New log entries created:

```
API_HEALTH_OK                    → API became healthy
API_HEALTH_TIMEOUT               → API never responded
REMEDIATION_API_HEALTH_FAILED    → API failed, attempting rollback
REMEDIATION_AUDIT_FAILED         → Audit failed, attempting rollback
REMEDIATION_VERIFICATION_TIMEOUT → Audit script timeout
REMEDIATION_VERIFICATION_ERROR   → Error running audit
REMEDIATION_AUDIT_NOT_FOUND      → Audit script missing
ROLLBACK_SUCCESS                 → Rollback completed
ROLLBACK_NO_BACKUP               → No backup file found
ROLLBACK_FILE_NOT_FOUND          → Backup file missing
ROLLBACK_PERMISSION_DENIED       → Need root privileges
ROLLBACK_ERROR                   → Other rollback error
```

---

## Output Examples

### Successful Remediation (FIXED ✓)

```
[*] Safety-First Remediation Verification for 1.2.5...
    Found backup file from env: /var/backups/cis-remediation/1.2.5_1702831222.bak
    [*] Waiting for API Server to become healthy (timeout: 60s)...
    [✓] API Server healthy after 3.2s
    [✓] API Server healthy. Running audit verification...
    [✓] VERIFIED: API healthy and audit passed.
    
Status: FIXED
Reason: [FIXED] Remediation verified (API + Audit).
```

### Failed Remediation (REMEDIATION_FAILED ❌)

```
[*] Safety-First Remediation Verification for 1.2.5...
    Found backup file: /var/backups/cis-remediation/1.2.5_1702831222.bak
    [*] Waiting for API Server to become healthy (timeout: 60s)...
    [✗] CRITICAL: API Server failed to become healthy within 60s.
    [!] Attempting automatic rollback for 1.2.5...
    [*] Rolling back: /etc/kubernetes/manifests/kube-apiserver.yaml
        From backup: /var/backups/cis-remediation/1.2.5_1702831222.bak
        Saved broken config: /etc/kubernetes/manifests/kube-apiserver.yaml.broken_20251217_143025
    [✓] Rollback completed successfully
    [✓] Rollback completed. Waiting for cluster recovery...

Status: REMEDIATION_FAILED
Reason: [REMEDIATION_FAILED] API Server failed to restart. Automatic rollback succeeded.
```

---

## Remediation Script Requirements

For Safety-First to work, remediation scripts should:

### 1. Create Backup BEFORE Modifying

```bash
#!/bin/bash

BACKUP_DIR="/var/backups/cis-remediation"
BACKUP_FILE="${BACKUP_DIR}/1.2.5_$(date +%s).bak"

mkdir -p "$BACKUP_DIR"
cp /etc/kubernetes/manifests/kube-apiserver.yaml "$BACKUP_FILE"

# Export for verification
export BACKUP_FILE="$BACKUP_FILE"
```

### 2. Make Changes

```bash
# Modify the manifest
sed -i 's/--audit-log-maxage=.*/--audit-log-maxage=30/' \
    /etc/kubernetes/manifests/kube-apiserver.yaml

# Or use Python helper for YAML
python3 scripts/yaml_safe_modifier.py \
    /etc/kubernetes/manifests/kube-apiserver.yaml \
    --key securityContext.privileged --value false
```

### 3. Return Proper Exit Code

```bash
# Return success only if changes were made
if grep -q "audit-log-maxage=30" /etc/kubernetes/manifests/kube-apiserver.yaml; then
    echo "[FIXED] Audit log max age set to 30 days"
    exit 0
else
    echo "[FAIL] Failed to set audit log max age"
    exit 1
fi
```

---

## Testing Checklist

- [ ] Run remediation for check with manifest modification (e.g., 1.2.5)
- [ ] Verify backup file created: `ls -la /var/backups/cis-remediation/`
- [ ] Verify "API Server healthy" message appears
- [ ] Verify audit verification runs and passes
- [ ] Verify status shows "FIXED" ✓
- [ ] Check activity log: `tail -f cis_runner.log | grep API_HEALTH`
- [ ] Artificially break remediation and verify rollback works
- [ ] Check `.broken_TIMESTAMP` files saved for debugging

---

## Performance Summary

| Operation | Time |
|-----------|------|
| Health check (success case) | 2-5 sec |
| Health check (timeout) | 60 sec |
| Audit verification | script timeout (default 60s) |
| Rollback operation | <1 sec |
| **Total per remediation** | **4-70 seconds** |

**Optimization:** Use `--fix-failed-only` flag to skip already-passing checks and only remediate failures from previous audit.

---

## Known Limitations

1. **Requires Root:** Manifest modifications and rollback need sudo
2. **Requires Backup:** Rollback fails if backup not created before remediation
3. **API Port Hardcoded:** Health check uses hardcoded `127.0.0.1:6443`
4. **Manual Checks:** Not covered by automatic verification (requires manual audit)
5. **Network Issues:** Health check requires connectivity to localhost

---

## Debugging Commands

```bash
# View all rollback events
grep "ROLLBACK" cis_runner.log

# Check broken configs saved
ls -la /etc/kubernetes/manifests/*.broken_*

# Monitor health checks
tail -f cis_runner.log | grep "API_HEALTH"

# Test health manually
curl -s -k https://127.0.0.1:6443/healthz

# Check backup directory
ls -la /var/backups/cis-remediation/

# View last activity logs
tail -50 cis_runner.log
```

---

## Summary

The Safety-First Remediation Flow provides:

1. **Automatic Backup Capture** - Before modifications
2. **Health Check Barrier** - Detects immediate failures
3. **Audit Verification** - Validates remediation effectiveness
4. **Intelligent Rollback** - Recovers to working state
5. **Comprehensive Logging** - Full audit trail
6. **No Manual Intervention** - Fully automated (unless backup missing)

This prevents infinite loops, cluster hangs, and cascading failures while ensuring full CIS compliance.
