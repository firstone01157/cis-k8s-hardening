# CIS Kubernetes Master Node Remediation Script

## Overview

`remediate_cis_kubernetes_master.sh` is a production-ready Bash script that safely remediates CIS Kubernetes Benchmark v1.34 control failures on Master Nodes.

## Target Controls

| Control | Description | File |
|---------|-------------|------|
| 1.2.5 | Ensure `--kubelet-certificate-authority` | kube-apiserver.yaml |
| 1.2.7 | Ensure `--authorization-mode` includes Node,RBAC | kube-apiserver.yaml |
| 1.2.30 | Ensure `--service-account-extend-token-expiration=false` | kube-apiserver.yaml |
| 1.3.6 | Ensure `--feature-gates` includes RotateKubeletServerCertificate | kube-controller-manager.yaml |
| 1.4.1 | Ensure `--profiling=false` | kube-scheduler.yaml |

## Installation

### Option 1: Run Locally
```bash
sudo /home/first/Project/cis-k8s-hardening/remediate_cis_kubernetes_master.sh
```

### Option 2: Run on Remote Master Node
```bash
ssh master@192.168.150.131 \
  sudo /home/master/cis-k8s-hardening/remediate_cis_kubernetes_master.sh
```

## Features

### Safety First
- **Timestamped Backups**: Creates backup before each modification
  - Location: `/etc/kubernetes/manifests/backups/`
  - Format: `filename.backup.YYYYMMDD_HHMMSS`

- **Root Privilege Check**: Validates sudo/root access

- **Prerequisite Validation**: Checks all dependencies before proceeding

### Intelligent Flag Management
- **Deduplication**: Removes old flag instances before adding new ones
- **Smart Merging**: Preserves existing values in comma-separated lists
- **Format Handling**: Manages complex formats like `--feature-gates=Key=Value`

### Verification
- **Change Confirmation**: Verifies each flag was applied correctly
- **Output Display**: Shows the actual modified lines

### Detailed Logging
- **Console Output**: Color-coded messages for easy reading
- **File Logging**: All operations logged to `/var/log/cis-remediation.log`
- **Per-Control Tracking**: Individual verification for each control

### Service Management
- **Kubelet Restart**: Automatically restarts kubelet after changes
- **Stabilization Wait**: Waits 5 seconds for service to stabilize
- **Status Verification**: Confirms kubelet is running after restart

## How It Works

### Step-by-Step Execution

1. **Validate Prerequisites**
   - Check root access
   - Verify Python 3 is available
   - Confirm all manifest files exist
   - Create backup directory

2. **Process Each Control** (5 controls total)
   - Create timestamped backup
   - Use Python hardener for intelligent flag updates
   - Verify changes were applied
   - Show actual modified content

3. **Apply Changes**
   - Restart kubelet service
   - Wait for stabilization
   - Verify kubelet is running

4. **Report Summary**
   - Display total controls processed
   - Show number successfully remediated
   - Report overall status

## Script Functions

### Logging Functions
- `log_info()`: Information messages (blue)
- `log_pass()`: Success messages (green)
- `log_fail()`: Error messages (red)
- `log_warn()`: Warning messages (yellow)

### Core Functions
- `validate_prerequisites()`: Pre-flight checks
- `create_backup()`: Creates timestamped backups
- `remediate_flag()`: Updates simple flags
- `remediate_authorization_mode()`: Handles Node,RBAC merging
- `remediate_feature_gates()`: Handles Key=Value list merging
- `verify_changes()`: Confirms modifications
- `restart_kubelet()`: Service restart and validation

## Example Output

```
╔════════════════════════════════════════════════════════════╗
║   CIS Kubernetes Master Node Remediation Script           ║
║   v1.0 - December 17, 2025                                ║
╚════════════════════════════════════════════════════════════╝

[INFO] Validating prerequisites...
[PASS] All prerequisites validated
[INFO] Starting remediation of 5 CIS controls...

================================
[INFO] Control 1.2.5: kubelet-certificate-authority
================================
[INFO] [1.2.5] Remediating: --kubelet-certificate-authority=/etc/kubernetes/pki/ca.crt
[PASS] Backup created: /etc/kubernetes/manifests/backups/kube-apiserver.yaml.backup.20251217_143022
[INFO] Updated flag: --kubelet-certificate-authority=/etc/kubernetes/pki/ca.crt
[PASS] [1.2.5] Flag remediated: --kubelet-certificate-authority
[PASS] [1.2.5] Verified: - --kubelet-certificate-authority=/etc/kubernetes/pki/ca.crt

[... similar output for controls 1.2.7, 1.2.30, 1.3.6, 1.4.1 ...]

[INFO] Restarting kubelet to apply changes...
[PASS] Kubelet restarted successfully

========================================================
[SUMMARY] CIS Kubernetes Master Node Remediation
========================================================
Total Controls: 5
Successfully Remediated: 5

[PASS] All controls successfully remediated!
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success - All controls remediated |
| 1 | Error - Failed to remediate (missing files, permissions, etc.) |

## Rollback Procedure

If remediation causes issues, restore from backup:

```bash
# List available backups
ls -lh /etc/kubernetes/manifests/backups/

# Restore a specific backup
sudo cp /etc/kubernetes/manifests/backups/kube-apiserver.yaml.backup.20251217_HHMMSS \
        /etc/kubernetes/manifests/kube-apiserver.yaml

# Restart kubelet
sudo systemctl restart kubelet
```

## Verification After Remediation

### 1. Check Kubelet Status
```bash
sudo systemctl status kubelet
```

### 2. Verify Applied Flags
```bash
grep "kubelet-certificate-authority" /etc/kubernetes/manifests/kube-apiserver.yaml
grep "authorization-mode" /etc/kubernetes/manifests/kube-apiserver.yaml
grep "service-account-extend-token-expiration" /etc/kubernetes/manifests/kube-apiserver.yaml
grep "feature-gates" /etc/kubernetes/manifests/kube-controller-manager.yaml
grep "profiling" /etc/kubernetes/manifests/kube-scheduler.yaml
```

### 3. Monitor Kubelet Logs
```bash
sudo journalctl -u kubelet -f
```

### 4. Run CIS Audit
Execute your CIS audit tool to confirm all controls now pass.

## Dependencies

- **Python 3**: Uses harden_manifests.py for intelligent flag management
- **Bash 4.0+**: Modern bash features
- **systemctl**: For kubelet service management
- **Standard Unix tools**: cp, grep

## Logging

- **Console Output**: Color-coded for easy reading
- **File Log**: `/var/log/cis-remediation.log`
- **Backup Location**: `/etc/kubernetes/manifests/backups/`

## Technical Details

### How Deduplication Works
```bash
# Before
- --authorization-mode=Node
- --authorization-mode=Node    # DUPLICATE

# After
- --authorization-mode=RBAC,Node    # Deduplicated and updated
```

### How Plugin Merging Works
```bash
# Before
- --enable-admission-plugins=NodeRestriction

# After
- --enable-admission-plugins=NodeRestriction,PodSecurityPolicy
```

### How Feature Gates Merging Works
```bash
# Before
- --feature-gates=SomeGate=true

# After
- --feature-gates=RotateKubeletServerCertificate=true,SomeGate=true
```

## Limitations & Considerations

1. **Root Required**: Script must run as root to modify system files
2. **Kubelet Restart**: Script automatically restarts kubelet (brief service interruption)
3. **Single Run**: Designed for one-time remediation (idempotent on repeated runs)
4. **File Format**: Assumes standard kubeadm-generated manifest format

## Troubleshooting

### Script Fails to Find Python
```bash
# Verify Python is installed
python3 --version

# If not installed:
apt-get install python3  # Debian/Ubuntu
yum install python3      # RHEL/CentOS
```

### Script Fails to Find Manifest Files
```bash
# Check if files exist
ls -la /etc/kubernetes/manifests/
```

### Kubelet Fails to Restart
```bash
# Check kubelet status
sudo systemctl status kubelet

# View logs
sudo journalctl -u kubelet -n 50
```

### Changes Not Applied
```bash
# Verify kubectl is running
kubectl get nodes

# Check kubelet logs
sudo journalctl -u kubelet -f
```

## Support & Documentation

- Script Location: `/home/first/Project/cis-k8s-hardening/remediate_cis_kubernetes_master.sh`
- Python Hardener: `/home/first/Project/cis-k8s-hardening/harden_manifests.py`
- Log File: `/var/log/cis-remediation.log`
- Backups: `/etc/kubernetes/manifests/backups/`

## Version

- **Script Version**: 1.0
- **Created**: December 17, 2025
- **CIS Benchmark**: v1.34

---

**Status**: ✅ Production Ready | **Tested**: ✅ Yes | **Deployed**: ✅ Yes
