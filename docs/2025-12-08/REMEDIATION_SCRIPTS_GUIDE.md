# CIS Kubernetes Benchmark Remediation Scripts - Quick Reference Guide

**Created:** December 8, 2025  
**Version:** 1.0  
**Target:** Kubernetes v1.30+ Master Node  
**CIS Benchmark:** Level 1 (Scored Controls)

---

## 📋 Table of Contents

1. [Scripts Overview](#scripts-overview)
2. [Individual Script Details](#individual-script-details)
3. [Running Scripts](#running-scripts)
4. [Batch Mode Guide](#batch-mode-guide)
5. [Verification Steps](#verification-steps)
6. [Troubleshooting](#troubleshooting)

---

## Scripts Overview

| # | Script | CIS Control | Target | Complexity |
|---|--------|-------------|--------|------------|
| 1 | `1.1.12_remediate.sh` | 1.1.12 | etcd ownership | Low |
| 2 | `1.2.5_remediate.sh` | 1.2.5 | API Server CA | Low |
| 3 | `1.2.15_remediate.sh` | 1.2.15 | API Server profiling | Low |
| 4 | `1.2.30_remediate.sh` | 1.2.30 | Token expiration | Low |
| 5 | `1.3.2_remediate.sh` | 1.3.2 | Controller Manager profiling | Low |
| 6 | `1.4.1_remediate.sh` | 1.4.1 | Scheduler profiling | Low |

---

## Individual Script Details

### Script 1: 1.1.12_remediate.sh
**Purpose:** Ensure etcd data directory ownership is set to `etcd:etcd`

**What it does:**
- Changes ownership of `/var/lib/etcd` and all files within
- Verifies ownership change was successful
- Logs all operations to `/var/log/cis-remediation.log`

**Run it:**
```bash
sudo ./Level_1_Master_Node/1.1.12_remediate.sh
```

**Key features:**
- No manifest modification (no pod restart)
- Recursive ownership change
- Sample file verification

---

### Script 2: 1.2.5_remediate.sh
**Purpose:** Ensure `--kubelet-certificate-authority` argument is set in API Server

**What it does:**
- Modifies `/etc/kubernetes/manifests/kube-apiserver.yaml`
- Adds `--kubelet-certificate-authority=/etc/kubernetes/pki/ca.crt`
- Creates backup before modification
- Verifies change was written correctly

**Run it:**
```bash
sudo ./Level_1_Master_Node/1.2.5_remediate.sh
```

**Batch mode:**
```bash
CIS_NO_RESTART=true sudo ./Level_1_Master_Node/1.2.5_remediate.sh
```

**Key features:**
- Searches for CA certificate in multiple locations
- Idempotent (safe to run multiple times)
- Auto-restore from backup on failure

---

### Script 3: 1.2.15_remediate.sh
**Purpose:** Ensure `--profiling` is set to `false` (API Server)

**What it does:**
- Modifies `/etc/kubernetes/manifests/kube-apiserver.yaml`
- Adds or updates `--profiling=false` flag
- Creates backup before changes
- Verifies the flag was added

**Run it:**
```bash
sudo ./Level_1_Master_Node/1.2.15_remediate.sh
```

**Batch mode:**
```bash
CIS_NO_RESTART=true sudo ./Level_1_Master_Node/1.2.15_remediate.sh
```

**Key features:**
- Removes old flag before adding new one (consistency)
- Checks if flag already correct
- Backup and restore on failure

---

### Script 4: 1.2.30_remediate.sh
**Purpose:** Ensure `--service-account-extend-token-expiration` is `false`

**What it does:**
- Modifies `/etc/kubernetes/manifests/kube-apiserver.yaml`
- Adds `--service-account-extend-token-expiration=false`
- Creates timestamped backup
- Verifies flag is present in manifest

**Run it:**
```bash
sudo ./Level_1_Master_Node/1.2.30_remediate.sh
```

**Batch mode:**
```bash
CIS_NO_RESTART=true sudo ./Level_1_Master_Node/1.2.30_remediate.sh
```

**Key features:**
- Prevents indefinite token validity
- Safe token expiration enforcement
- Full error recovery

---

### Script 5: 1.3.2_remediate.sh
**Purpose:** Ensure `--profiling` is set to `false` (Controller Manager)

**What it does:**
- Modifies `/etc/kubernetes/manifests/kube-controller-manager.yaml`
- Adds or updates `--profiling=false` flag
- Creates backup before modification
- Verifies flag was added correctly

**Run it:**
```bash
sudo ./Level_1_Master_Node/1.3.2_remediate.sh
```

**Batch mode:**
```bash
CIS_NO_RESTART=true sudo ./Level_1_Master_Node/1.3.2_remediate.sh
```

**Key features:**
- Disables performance profiling
- Idempotent operations
- Automatic restore on failure

---

### Script 6: 1.4.1_remediate.sh
**Purpose:** Ensure `--profiling` is set to `false` (Scheduler)

**What it does:**
- Modifies `/etc/kubernetes/manifests/kube-scheduler.yaml`
- Adds or updates `--profiling=false` flag
- Backup before changes
- Verification after modification

**Run it:**
```bash
sudo ./Level_1_Master_Node/1.4.1_remediate.sh
```

**Batch mode:**
```bash
CIS_NO_RESTART=true sudo ./Level_1_Master_Node/1.4.1_remediate.sh
```

**Key features:**
- Protects scheduler details
- Safe, idempotent modification
- Full audit trail

---

## Running Scripts

### Single Script
```bash
cd /home/first/Project/cis-k8s-hardening
sudo ./Level_1_Master_Node/1.1.12_remediate.sh
```

### All Scripts in Sequence
```bash
cd Level_1_Master_Node
for script in 1.1.12_remediate.sh 1.2.5_remediate.sh 1.2.15_remediate.sh 1.2.30_remediate.sh 1.3.2_remediate.sh 1.4.1_remediate.sh; do
  echo "Running $script..."
  sudo ./$script
  sleep 2
done
```

### With Custom Logging
```bash
sudo ./Level_1_Master_Node/1.2.5_remediate.sh 2>&1 | tee -a my_remediation.log
```

### Dry Run (Preview only)
```bash
# Scripts don't have a dry-run mode, but you can check what they'll do:
grep -E "sed|chown|cp" ./Level_1_Master_Node/1.2.5_remediate.sh
```

---

## Batch Mode Guide

### What is Batch Mode?

When running multiple scripts that modify manifests, each modification can trigger a static pod restart. Multiple rapid restarts can trigger systemd's start-limit protection, causing failures.

**Batch Mode Solution:** Set `CIS_NO_RESTART=true` to prevent manifest files from being moved (which triggers restarts).

### Batch Mode Workflow

```bash
# 1. Set batch mode flag
export CIS_NO_RESTART=true

# 2. Run all scripts that modify manifests
sudo ./Level_1_Master_Node/1.2.5_remediate.sh
sudo ./Level_1_Master_Node/1.2.15_remediate.sh
sudo ./Level_1_Master_Node/1.2.30_remediate.sh
sudo ./Level_1_Master_Node/1.3.2_remediate.sh
sudo ./Level_1_Master_Node/1.4.1_remediate.sh

# 3. Run scripts without batch mode (allows restarts)
unset CIS_NO_RESTART
sudo ./Level_1_Master_Node/1.1.12_remediate.sh

# 4. Manually restart services (optional, they'll restart naturally)
sudo systemctl restart kubelet

# 5. Wait for pods to stabilize
sleep 15

# 6. Verify all pods are running
kubectl get pods -n kube-system | grep -E "(apiserver|controller|scheduler)"
```

### When to Use Batch Mode

- ✅ Applying multiple manifest changes at once
- ✅ Want to avoid cascading pod restarts
- ✅ Running in a maintenance window
- ❌ Don't use when applying single changes
- ❌ Don't use in production without testing

---

## Verification Steps

### After Each Script

1. **Check exit code:**
   ```bash
   sudo ./Level_1_Master_Node/1.2.5_remediate.sh
   echo $?  # Should print 0 for success
   ```

2. **Check logs:**
   ```bash
   tail -20 /var/log/cis-remediation.log
   ```

3. **Check backups:**
   ```bash
   ls -la /var/backups/kubernetes/
   ```

### After All Scripts

1. **Verify etcd ownership:**
   ```bash
   stat -c "%U:%G" /var/lib/etcd
   # Expected: etcd:etcd
   ```

2. **Verify API Server flags:**
   ```bash
   grep -E "(kubelet-certificate|profiling|service-account-extend)" \
     /etc/kubernetes/manifests/kube-apiserver.yaml
   
   # Expected:
   # - --kubelet-certificate-authority=/etc/kubernetes/pki/ca.crt
   # - --profiling=false
   # - --service-account-extend-token-expiration=false
   ```

3. **Verify Controller Manager:**
   ```bash
   grep "profiling=false" /etc/kubernetes/manifests/kube-controller-manager.yaml
   # Expected: - --profiling=false
   ```

4. **Verify Scheduler:**
   ```bash
   grep "profiling=false" /etc/kubernetes/manifests/kube-scheduler.yaml
   # Expected: - --profiling=false
   ```

5. **Check pod status:**
   ```bash
   kubectl get pods -n kube-system | grep -E "kube-(apiserver|controller|scheduler)"
   # All should show "Running" status
   ```

6. **Check pod logs:**
   ```bash
   kubectl logs -n kube-system -l component=kube-apiserver --tail=20
   kubectl logs -n kube-system -l component=kube-controller-manager --tail=20
   kubectl logs -n kube-system -l component=kube-scheduler --tail=20
   ```

---

## Troubleshooting

### Pod Restart Issues

**Problem:** Static pods keep restarting

**Solution:**
```bash
# Reset systemd failures
sudo systemctl reset-failed kubelet

# Stop kubelet
sudo systemctl stop kubelet

# Check manifest syntax
sudo kubelet --config=/etc/kubernetes/kubelet.conf --validate-only

# Restore from backup if needed
sudo cp /var/backups/kubernetes/TIMESTAMP_cis/* /etc/kubernetes/manifests/

# Restart kubelet
sudo systemctl start kubelet
```

### Verification Fails

**Problem:** Script says "Verification failed"

**Restore from backup:**
```bash
# Find the backup
ls -la /var/backups/kubernetes/

# Restore specific manifest
sudo cp /var/backups/kubernetes/TIMESTAMP_cis/kube-apiserver.yaml.bak \
  /etc/kubernetes/manifests/kube-apiserver.yaml

# Wait for pod to restart
sleep 10

# Check pod status
kubectl get pods -n kube-system -l component=kube-apiserver
```

### Flag Not Found

**Problem:** Script can't find the flag to modify

**Check manifest exists:**
```bash
ls -la /etc/kubernetes/manifests/kube-apiserver.yaml

# If missing, check if custom location
find / -name "kube-apiserver.yaml" 2>/dev/null
```

### Permission Issues

**Problem:** "Permission denied" errors

**Solution:**
```bash
# All scripts require sudo
sudo ./Level_1_Master_Node/1.1.12_remediate.sh

# Or run as root
su -
./Level_1_Master_Node/1.1.12_remediate.sh
```

---

## Quick Commands

```bash
# Run one script
sudo ./Level_1_Master_Node/1.1.12_remediate.sh

# Run all scripts with batch mode
cd Level_1_Master_Node && \
export CIS_NO_RESTART=true && \
for s in 1.2.5 1.2.15 1.2.30 1.3.2 1.4.1; do
  sudo ./${s}_remediate.sh
done && \
unset CIS_NO_RESTART && \
sudo ./1.1.12_remediate.sh && \
sudo systemctl restart kubelet

# Check all changes
grep -rE "(profiling=false|kubelet-certificate|service-account-extend)" \
  /etc/kubernetes/manifests/

# See all logs
sudo tail -100 /var/log/cis-remediation.log

# List all backups
ls -la /var/backups/kubernetes/*/

# Restore all from latest backup
sudo cp /var/backups/kubernetes/$(ls -t /var/backups/kubernetes/ | head -1)/* \
  /etc/kubernetes/manifests/
```

---

## Notes

- All scripts are **idempotent** (safe to run multiple times)
- All scripts create **timestamped backups** before modifications
- All scripts use **grep-based verification** to confirm changes
- All scripts log to **both stdout and `/var/log/cis-remediation.log`**
- All scripts use **bash strict mode** for error handling
- All scripts are **Kubernetes v1.30+ compatible**
- All scripts support **batch mode** via `CIS_NO_RESTART` environment variable

---

**Author:** DevSecOps Team  
**Date:** December 8, 2025  
**Status:** Production Ready
