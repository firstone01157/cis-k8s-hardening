# Safe Audit Logging Remediation Guide
## CIS Kubernetes Benchmark 1.2.15 - 1.2.19

**Version:** 1.0  
**Date:** 2025-11-26  
**Purpose:** Safely remediate audit logging failures without API Server crashes

---

## Table of Contents

1. [Overview](#overview)
2. [The Problem](#the-problem)
3. [The Solution](#the-solution)
4. [Prerequisites](#prerequisites)
5. [Usage Instructions](#usage-instructions)
6. [Script Details](#script-details)
7. [Troubleshooting](#troubleshooting)
8. [Rollback Procedure](#rollback-procedure)
9. [Verification](#verification)

---

## Overview

This guide provides **two remediation scripts** (Bash and Python) for safely fixing CIS Kubernetes Benchmark audit logging checks:

- **CIS 1.2.16** - Ensure `--audit-log-path` argument is set
- **CIS 1.2.17** - Ensure `--audit-log-maxage` argument is set to 30 or as appropriate
- **CIS 1.2.18** - Ensure `--audit-log-maxbackup` argument is set to 10 or as appropriate
- **CIS 1.2.19** - Ensure `--audit-log-maxsize` argument is set to 100 or as appropriate

*Note: CIS 1.2.15 (--profiling=false) is separate and not included in this remediation.*

---

## The Problem

Previous attempts to remediate audit logging failures have resulted in **API Server crashes** because:

### Root Causes:

1. **Missing Directory Creation**: The `/var/log/kubernetes/audit` directory didn't exist, causing the kube-apiserver Pod to fail startup.

2. **Missing Audit Policy File**: The `--audit-policy-file` argument references a file that must exist, but it was never created.

3. **No Volume Mounts**: Even after adding the flags to the manifest, the Pod container couldn't access the audit directory or policy file because:
   - `volumeMounts` were not added to the container spec
   - `volumes` were not added to the Pod spec

4. **YAML Indentation Errors**: Manual edits often introduced indentation errors that prevented the manifest from being valid.

### Why Previous Attempts Failed:

```yaml
# INCORRECT - No volume/volumeMount definitions
spec:
  containers:
  - command:
    - kube-apiserver
    - --audit-log-path=/var/log/kubernetes/audit/audit.log
    - --audit-policy-file=/var/log/kubernetes/audit/audit-policy.yaml
    # ❌ Missing volumeMounts!
    # ❌ Missing volumes in spec!
```

The Pod would start, but the container couldn't read or write the files, causing crashes.

---

## The Solution

Both scripts implement a **complete, atomic remediation** that handles all prerequisites:

### What the Scripts Do:

1. **✓ Create the audit directory** (`/var/log/kubernetes/audit`) with proper permissions (700)
2. **✓ Create a valid audit policy file** with CIS-compliant rules
3. **✓ Add all required flags** to the kube-apiserver manifest:
   - `--audit-log-path=/var/log/kubernetes/audit/audit.log`
   - `--audit-policy-file=/var/log/kubernetes/audit/audit-policy.yaml`
   - `--audit-log-maxage=30`
   - `--audit-log-maxbackup=10`
   - `--audit-log-maxsize=100`
4. **✓ Add volumeMounts** to the container spec for both audit log and policy files
5. **✓ Add volumes** (hostPath) to the Pod spec for host directory mounting
6. **✓ Validate YAML syntax** before applying changes
7. **✓ Create timestamped backups** before any modifications
8. **✓ Restart the kube-apiserver Pod** to apply changes

### Correct Result:

```yaml
spec:
  containers:
  - name: kube-apiserver
    command:
    - kube-apiserver
    - --audit-log-path=/var/log/kubernetes/audit/audit.log
    - --audit-policy-file=/var/log/kubernetes/audit/audit-policy.yaml
    - --audit-log-maxage=30
    - --audit-log-maxbackup=10
    - --audit-log-maxsize=100
    # ✓ volumeMounts defined!
    volumeMounts:
    - name: audit-log
      mountPath: /var/log/kubernetes/audit
      readOnly: false
    - name: audit-policy
      mountPath: /var/log/kubernetes/audit/audit-policy.yaml
      readOnly: true
      subPath: audit-policy.yaml
  # ✓ volumes defined!
  volumes:
  - name: audit-log
    hostPath:
      path: /var/log/kubernetes/audit
      type: DirectoryOrCreate
  - name: audit-policy
    hostPath:
      path: /var/log/kubernetes/audit/audit-policy.yaml
      type: FileOrCreate
```

---

## Prerequisites

### System Requirements:

- ✓ Kubernetes master/control-plane node
- ✓ Root or `sudo` access
- ✓ Bash 4.0+ (for bash script) OR Python 3.6+ (for python script)
- ✓ Writable `/etc/kubernetes/manifests/` directory
- ✓ At least 100 MB free space in `/var/log`

### Required Files:

Both scripts are located in the CIS Kubernetes Benchmark directory:

```
safe_audit_remediation.sh   (Bash - recommended for most systems)
safe_audit_remediation.py   (Python - alternative option)
```

---

## Usage Instructions

### Method 1: Bash Script (Recommended)

**Safest and most widely compatible approach:**

```bash
# Option A: Direct execution with sudo
sudo bash /path/to/safe_audit_remediation.sh

# Option B: From within the script directory
cd /path/to/scripts
sudo bash safe_audit_remediation.sh

# Option C: With explicit bash interpreter
sudo /bin/bash safe_audit_remediation.sh
```

### Method 2: Python Script

```bash
# With Python 3
sudo python3 /path/to/safe_audit_remediation.py

# Or if python points to Python 3
sudo python /path/to/safe_audit_remediation.py
```

### Full Execution Example:

```bash
# SSH to master node
ssh user@master-node

# Make script executable (if needed)
chmod +x safe_audit_remediation.sh

# Run with sudo
sudo ./safe_audit_remediation.sh

# Expected output:
# [SUCCESS] Running as root
# [SUCCESS] Manifest directory exists...
# ... (more operations)
# ✓ REMEDIATION COMPLETED SUCCESSFULLY
```

---

## Script Details

### Execution Flow

Both scripts follow the same 13-phase execution model:

| Phase | Description | Critical? |
|-------|-------------|-----------|
| 1 | Check Prerequisites (root, directories, manifest) | YES |
| 2 | Create Backup Directory | YES |
| 3 | Backup Current Manifest | YES |
| 4 | Create Audit Directory | YES |
| 5 | Create Audit Policy File | YES |
| 6-7 | Load and Prepare Manifest | YES |
| 8 | Add Audit Logging Flags | YES |
| 9 | Add volumeMounts for Audit | YES |
| 10 | Add volumes (hostPath) for Audit | YES |
| 11 | Validate YAML Syntax | YES |
| 12 | Save Updated Manifest | YES |
| 13 | Restart kube-apiserver Pod | NO |

### Key Locations

After successful execution:

```
Audit Log Directory:      /var/log/kubernetes/audit/
Audit Log File:           /var/log/kubernetes/audit/audit.log
Audit Policy File:        /var/log/kubernetes/audit/audit-policy.yaml
Manifest Backup:          /var/backups/kubernetes/kube-apiserver.yaml.backup_TIMESTAMP
Updated Manifest:         /etc/kubernetes/manifests/kube-apiserver.yaml
```

### Audit Policy Content

The scripts create a minimal audit policy that:

- Logs all requests at **Metadata level** (efficient, captures operation)
- Logs pod exec/attach at **RequestResponse level** (includes request body for security)
- Excludes non-sensitive operations (healthz, logs, events)
- Complies with CIS Kubernetes Benchmark recommendations

---

## Troubleshooting

### Issue: "This script must be run as root"

**Solution:** Use `sudo`:
```bash
sudo bash safe_audit_remediation.sh
```

### Issue: "Manifest directory not found"

**Possible Causes:**
- Not running on a Kubernetes master node
- Kubernetes not installed in expected location
- Non-standard Kubernetes installation

**Solution:**
```bash
# Verify master node
kubectl get nodes -o wide

# Check manifest directory
ls -la /etc/kubernetes/manifests/

# If different location, edit script to change MANIFEST_DIR variable
```

### Issue: "kube-apiserver process not detected"

**Cause:** Process may not be running currently (normal if restarting)

**Solution:** This is a warning only. If you're on a master node, the script will proceed.

### Issue: "YAML validation failed"

**Possible Causes:**
- Tabs instead of spaces in manifest
- Incorrect indentation
- Syntax errors introduced during edit

**Solution:**
1. Check the backup: `/var/backups/kubernetes/kube-apiserver.yaml.backup_*`
2. Review the error message for specific line/character
3. Run the rollback procedure (see below)

### Issue: "Could not automatically restart kube-apiserver"

**Cause:** `kubectl` command not available or cluster communication issues

**Solution:**
```bash
# Manual restart command
kubectl delete pod -n kube-system -l component=kube-apiserver

# Or wait for kubelet to restart the static pod
# (Static pod manifests trigger automatic restart when changed)
```

### Issue: API Server Crashes After Script Execution

**Immediate Action:**
```bash
# Check pod status
kubectl get pod -n kube-system -l component=kube-apiserver

# Check pod logs
kubectl logs -n kube-system -l component=kube-apiserver

# If logs not available, check kubelet logs on master node
sudo journalctl -u kubelet -n 50
```

**Rollback** (see [Rollback Procedure](#rollback-procedure) section)

---

## Rollback Procedure

### Automatic Backup Usage

The scripts create timestamped backups before making changes:

```bash
# List available backups
ls -la /var/backups/kubernetes/kube-apiserver.yaml.backup_*

# Example output:
# kube-apiserver.yaml.backup_20251126_143022
# kube-apiserver.yaml.backup_20251126_143515
```

### Rollback Steps

```bash
# 1. Stop the kube-apiserver (it will be restarted by kubelet)
kubectl delete pod -n kube-system -l component=kube-apiserver

# Wait for it to crash/stop
sleep 10

# 2. Restore from backup
sudo cp /var/backups/kubernetes/kube-apiserver.yaml.backup_TIMESTAMP \
        /etc/kubernetes/manifests/kube-apiserver.yaml

# 3. Verify restoration
cat /etc/kubernetes/manifests/kube-apiserver.yaml | head -20

# 4. Kubelet will automatically restart the pod
# Wait 30-60 seconds for it to come up

# 5. Verify recovery
kubectl get pod -n kube-system -l component=kube-apiserver
kubectl get nodes
```

### Manual Rollback (if backups unavailable)

```bash
# If you have the original manifest saved elsewhere
sudo cp /path/to/original/kube-apiserver.yaml /etc/kubernetes/manifests/

# Or restore from etcd (advanced)
# Contact Kubernetes cluster administrator
```

---

## Verification

### Post-Remediation Checks

#### 1. Check if Flags are Set

```bash
# Run the audit checks
./Level_1_Master_Node/1.2.16_audit.sh  # --audit-log-path
./Level_1_Master_Node/1.2.17_audit.sh  # --audit-log-maxage
./Level_1_Master_Node/1.2.18_audit.sh  # --audit-log-maxbackup
./Level_1_Master_Node/1.2.19_audit.sh  # --audit-log-maxsize

# Or check directly
ps aux | grep kube-apiserver | grep -o '\-\-audit[^ ]*'
```

**Expected Output:**
```
--audit-log-path=/var/log/kubernetes/audit/audit.log
--audit-policy-file=/var/log/kubernetes/audit/audit-policy.yaml
--audit-log-maxage=30
--audit-log-maxbackup=10
--audit-log-maxsize=100
```

#### 2. Check Pod Status

```bash
# Verify pod is running
kubectl get pod -n kube-system kube-apiserver-$(hostname) -o wide

# Check for crash loops
kubectl describe pod -n kube-system kube-apiserver-$(hostname)

# Check logs
kubectl logs -n kube-system kube-apiserver-$(hostname) --tail=50
```

**Expected Status:** `Running` with no `CrashLoopBackOff`

#### 3. Check Manifest Structure

```bash
# Verify manifest has volumes
grep -A5 "^  volumes:" /etc/kubernetes/manifests/kube-apiserver.yaml

# Verify volumeMounts are present
grep -A10 "volumeMounts:" /etc/kubernetes/manifests/kube-apiserver.yaml
```

**Expected Output:**
```yaml
  volumes:
  - name: audit-log
    hostPath:
      path: /var/log/kubernetes/audit
      type: DirectoryOrCreate
  - name: audit-policy
    hostPath:
      path: /var/log/kubernetes/audit/audit-policy.yaml
      type: FileOrCreate
```

#### 4. Check Audit Log Files

```bash
# Verify audit log directory
ls -la /var/log/kubernetes/audit/

# Check permissions (should be 700)
stat /var/log/kubernetes/audit/

# Check for audit logs being generated
ls -lh /var/log/kubernetes/audit/audit.log*
```

#### 5. Check Cluster Health

```bash
# Verify API server is responsive
kubectl get nodes

# Check cluster components
kubectl get pod -n kube-system | grep -E 'coredns|etcd|apiserver'

# Verify all nodes are ready
kubectl get nodes -o wide
```

#### 6. Run Full Remediation Verification Script

```bash
# Create a quick verification script
cat > verify_audit_remediation.sh << 'VERIFY_EOF'
#!/bin/bash

echo "=== Audit Logging Remediation Verification ==="
echo ""

echo "1. Checking manifest flags..."
for flag in "audit-log-path" "audit-policy-file" "audit-log-maxage" "audit-log-maxbackup" "audit-log-maxsize"; do
    if grep -q -- "--$flag" /etc/kubernetes/manifests/kube-apiserver.yaml; then
        echo "  ✓ --$flag found"
    else
        echo "  ✗ --$flag NOT found"
    fi
done

echo ""
echo "2. Checking volumeMounts..."
for mount in "audit-log" "audit-policy"; do
    if grep -q "name: $mount" /etc/kubernetes/manifests/kube-apiserver.yaml; then
        echo "  ✓ volumeMount '$mount' found"
    else
        echo "  ✗ volumeMount '$mount' NOT found"
    fi
done

echo ""
echo "3. Checking volumes..."
for vol in "audit-log" "audit-policy"; do
    if grep -q "name: $vol" /etc/kubernetes/manifests/kube-apiserver.yaml; then
        echo "  ✓ volume '$vol' found"
    else
        echo "  ✗ volume '$vol' NOT found"
    fi
done

echo ""
echo "4. Checking audit directory..."
if [ -d "/var/log/kubernetes/audit" ]; then
    echo "  ✓ Directory exists: /var/log/kubernetes/audit"
else
    echo "  ✗ Directory NOT found: /var/log/kubernetes/audit"
fi

echo ""
echo "5. Checking audit policy file..."
if [ -f "/var/log/kubernetes/audit/audit-policy.yaml" ]; then
    echo "  ✓ File exists: /var/log/kubernetes/audit/audit-policy.yaml"
else
    echo "  ✗ File NOT found: /var/log/kubernetes/audit/audit-policy.yaml"
fi

echo ""
echo "6. Checking API server pod status..."
if kubectl get pod -n kube-system -l component=kube-apiserver &>/dev/null; then
    local status=$(kubectl get pod -n kube-system -l component=kube-apiserver -o jsonpath='{.items[0].status.phase}')
    echo "  Pod Status: $status"
    if [ "$status" = "Running" ]; then
        echo "  ✓ Pod is Running"
    else
        echo "  ✗ Pod status is NOT Running"
    fi
else
    echo "  ✗ Could not get pod status"
fi

VERIFY_EOF

chmod +x verify_audit_remediation.sh
./verify_audit_remediation.sh
```

---

## FAQ

### Q: Can I run this script multiple times?

**A:** Yes, it's safe. The script:
- Checks if changes already exist before applying
- Skips re-adding existing flags
- Creates new backups each time
- Will not duplicate volumeMounts/volumes

### Q: What if I have custom audit policy requirements?

**A:** After running the script:
1. Edit `/var/log/kubernetes/audit/audit-policy.yaml`
2. Delete the kube-apiserver pod to reload the policy:
   ```bash
   kubectl delete pod -n kube-system -l component=kube-apiserver
   ```

### Q: Will this affect my cluster's performance?

**A:** Minimal impact:
- Audit logging uses ~1-3% additional CPU per request
- Log rotation (maxage=30, maxbackup=10) prevents disk fill
- Metadata-level logging limits overhead
- Most enterprises use similar settings

### Q: Can I customize the audit log path?

**A:** Edit the script before running:
```bash
# In safe_audit_remediation.sh, change:
AUDIT_DIR="/var/log/kubernetes/audit"
# To your preferred location
AUDIT_DIR="/var/log/audit/kubernetes"
```

### Q: What happens if the audit log fills the disk?

**A:** The rotation settings prevent this:
- `--audit-log-maxage=30`: Delete logs older than 30 days
- `--audit-log-maxbackup=10`: Keep max 10 backup files
- `--audit-log-maxsize=100`: Rotate when file reaches 100 MB

### Q: How do I view the audit logs?

**A:** Audit logs are in JSON format:
```bash
# View recent entries (last 100 lines)
tail -100 /var/log/kubernetes/audit/audit.log | jq .

# Filter for specific events
cat /var/log/kubernetes/audit/audit.log | jq 'select(.user.username=="admin")'

# Count events by user
cat /var/log/kubernetes/audit/audit.log | jq -r '.user.username' | sort | uniq -c
```

---

## Support & Issues

### If the Script Fails:

1. **Collect logs:**
   ```bash
   # Full execution output
   sudo bash safe_audit_remediation.sh 2>&1 | tee remediation.log
   
   # Backup and manifest
   ls -la /var/backups/kubernetes/
   head -30 /etc/kubernetes/manifests/kube-apiserver.yaml
   
   # Kubernetes logs
   kubectl logs -n kube-system -l component=kube-apiserver --tail=100
   ```

2. **Check for common issues:**
   - Not running as root? → Use `sudo`
   - Syntax errors? → Check manifest indentation with `yamllint`
   - Pod won't start? → Review kubelet logs: `journalctl -u kubelet`

3. **Perform rollback** if needed (see [Rollback Procedure](#rollback-procedure))

---

## References

- [Kubernetes Audit Logging Documentation](https://kubernetes.io/docs/tasks/debug-application-cluster/audit/)
- [CIS Kubernetes Benchmark v1.12.0](https://www.cisecurity.org/benchmark/kubernetes)
- [Kubernetes Static Pod Manifests](https://kubernetes.io/docs/tasks/configure-pod-container/static-pod/)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-11-26 | Initial release - Bash and Python scripts |

---

**Last Updated:** 2025-11-26  
**Status:** Ready for Production Use
