# CIS Kubernetes Hardening - Detailed Guide

> **For comprehensive details and advanced features**

---

## Table of Contents

1. [Advanced Usage](#advanced-usage)
2. [Configuration Details](#configuration-details)
3. [Troubleshooting](#troubleshooting)
4. [Check Categories](#check-categories)
5. [Smart Checks Explanation](#smart-checks-explanation)
6. [Batch Operations](#batch-operations)

---

## Advanced Usage

### Python Runner with Verbosity

```bash
# Standard mode
python3 cis_k8s_unified.py

# Verbose mode (show details)
python3 cis_k8s_unified.py -v

# Debug mode (show all output)
python3 cis_k8s_unified.py -vv
```

### Direct Script Execution

```bash
# Master node audit
bash Level_1_Master_Node/1.1.1_audit.sh
bash Level_1_Master_Node/1.2.1_audit.sh

# Worker node audit
bash Level_1_Worker_Node/4.1.1_audit.sh
bash Level_1_Worker_Node/4.2.1_audit.sh

# Remediation
sudo bash Level_1_Master_Node/1.1.1_remediate.sh
```

### Using Environment Variables

```bash
# Set kubelet configuration
export CONFIG_ANONYMOUS_AUTH="false"
export CONFIG_WEBHOOK_AUTH="true"
export CONFIG_WEBHOOK_AUTHZ="true"
export CONFIG_MAKE_IPTABLES_UTIL_CHAINS="true"
export CONFIG_PROTECT_KERNEL_DEFAULTS="false"

# Run remediation
python3 cis_k8s_unified.py
```

### Kubelet Hardening Tool

```bash
# Interactive mode
python3 harden_kubelet.py

# With environment variables
CONFIG_ANONYMOUS_AUTH=false \
CONFIG_WEBHOOK_AUTH=true \
python3 harden_kubelet.py

# Output includes:
# - Loading existing config
# - Validating settings
# - Writing new config
# - Restarting kubelet
# - Verifying changes
```

---

## Configuration Details

### Main Config File: `config/cis_config.json`

```json
{
  "excluded_rules": {
    "5.1.1": "Excluded because custom RBAC"
  },
  "component_mapping": {
    "API_Server": ["1.1.1", "1.1.2", "1.1.3"],
    "Kubelet": ["4.1.1", "4.2.1"]
  },
  "remediation_config": {
    "global": {
      "backup_enabled": true,
      "backup_dir": "/var/backups/cis-remediation",
      "dry_run": false,
      "wait_for_api": true,
      "api_check_interval": 5,
      "api_max_retries": 60,
      "api_settle_time": 15
    },
    "checks": {
      "1.1.1": {
        "enabled": true,
        "skip": false
      },
      "4.1.3": {
        "enabled": true,
        "description": "Smart check - respects defaults"
      }
    },
    "environment_overrides": {
      "CONFIG_ANONYMOUS_AUTH": "false",
      "CONFIG_WEBHOOK_AUTH": "true"
    }
  }
}
```

### Key Configuration Options

| Option | Type | Purpose | ตัวเลือก |
|--------|------|---------|-----------|
| `backup_enabled` | bool | Enable/disable backups | บันทึกสำรอง |
| `dry_run` | bool | Show changes without applying | แสดงเฉพาะ |
| `wait_for_api` | bool | Wait for cluster health | รอคลัสเตอร์ |
| `api_check_interval` | int | Health check interval (sec) | ช่วงเวลา |
| `api_max_retries` | int | Max retry attempts | ลองใหม่สูงสุด |
| `protect_kernel_defaults` | bool | Strict kernel settings | โหมดเข้มงวด |

---

## Troubleshooting

### Issue: Permission Denied

**Cause:** Running remediation without sudo

**Solution:**
```bash
# Use sudo
sudo bash Level_1_Master_Node/1.1.1_remediate.sh

# Or set SUDO_USER
sudo -u root bash script.sh
```

---

### Issue: Script Not Found

**Cause:** Scripts not executable or wrong path

**Solution:**
```bash
# Make all scripts executable
chmod +x *.sh
chmod +x Level_*_*/*.sh
chmod +x scripts/*.sh

# Verify location
pwd  # Should be in cis-k8s-hardening/
ls -l Level_1_Master_Node/1.1.1_audit.sh
```

---

### Issue: Config File Not Found

**Cause:** Kubelet config at non-standard location

**Solution:**
```bash
# Find kubelet config
ps aux | grep kubelet | grep -i config

# Common locations:
# - /var/lib/kubelet/config.yaml
# - /etc/kubernetes/kubelet.conf
# - /etc/kubernetes/kubelet-kubeadm.conf

# Check kubelet service
systemctl cat kubelet
```

---

### Issue: Remediation Failed / Changes Didn't Apply

**Cause:** Service didn't restart or config not saved

**Solution:**
```bash
# 1. Check kubelet status
systemctl status kubelet

# 2. View kubelet logs
journalctl -u kubelet -n 100
journalctl -u kubelet -f  # Follow logs

# 3. Verify changes persisted
cat /var/lib/kubelet/config.yaml | grep anonymousAuth

# 4. Check for backup files
ls -la /var/lib/kubelet/config.yaml*

# 5. Manually restart
sudo systemctl restart kubelet
sudo systemctl status kubelet
```

---

### Issue: API Server Restart Caused Cluster Issues

**Cause:** Changes to API server arguments caused restart

**Solution:**
```bash
# Check cluster health
kubectl get nodes
kubectl get pods -n kube-system

# View API server logs
journalctl -u kube-apiserver -n 50

# Restore from backup
# Look in /var/backups/cis-remediation/
ls -la /var/backups/cis-remediation/
```

---

## Check Categories

### CIS 1.x - API Server Checks

| Check | Category | Manual | ประเภท |
|-------|----------|--------|---------|
| 1.1.1-1.1.21 | Authentication & Authorization | Some | ตรวจสอบ |
| 1.2.1-1.2.30 | Logging & Audit | Some | บันทึก |
| 1.3.x | Misc Configuration | Some | อื่นๆ |

### CIS 2.x - etcd Checks

| Check | Category | Manual |
|-------|----------|--------|
| 2.1.x | Client Authentication | Yes |
| 2.2.x | Encryption & TLS | Yes |

### CIS 4.x - Kubelet Checks

| Check | Category | Smart |
|-------|----------|-------|
| 4.1.x | File Permissions | Yes (4.1.3, 4.1.4) |
| 4.2.x | Kubelet Config | Some |
| 4.3.x | Container Runtime | Some |

### CIS 5.x - RBAC & Pod Security

| Check | Category | Manual |
|-------|----------|--------|
| 5.1.x | RBAC Checks | Yes |
| 5.2.x | Pod Security | Varies |
| 5.3.x | Network Policies | Manual |

---

## Smart Checks Explanation

### What are Smart Checks?

Smart checks understand the difference between:
- ✅ Secure Kubeadm defaults (PASS)
- ✅ Properly configured settings (PASS)
- ❌ Missing or incorrect configuration (FAIL)

### Examples

#### Check 4.1.3: kube-proxy --kubeconfig
```bash
# This check is SMART because:

IF --kubeconfig NOT configured
    # Using in-cluster service account (secure default)
    → PASS

ELSE IF --kubeconfig file doesn't exist
    # Configuration error
    → FAIL

ELSE IF file permissions wrong (not 600)
    # Security issue
    → FIX (chmod 600)
```

#### Check 4.1.4: kube-proxy --kubeconfig ownership
```bash
# This check is SMART because:

IF --kubeconfig NOT configured
    # Using default (secure)
    → PASS

ELSE IF file ownership wrong (not root:root)
    # Security issue
    → FIX (chown root:root)
```

---

## Batch Operations

### Update All Manual Exit Codes

```bash
# Safe method with verification
bash batch_update_manual_exit_codes.sh

# Or one-liner
cd /home/first/Project/cis-k8s-hardening && \
find . -name "*.sh" ! -path "*/backups/*" | while read f; do \
  if head -20 "$f" | grep -q "# Title:.*\(Manual\)"; then \
    sed -i 's/^exit 0$/exit 3/' "$f"; \
  fi; \
done
```

### Remediate All Master Checks

```bash
# Level 1 only
for script in Level_1_Master_Node/*_remediate.sh; do
  echo "Running: $script"
  sudo bash "$script"
done

# All levels
for script in Level_*_Master_Node/*_remediate.sh; do
  echo "Running: $script"
  sudo bash "$script"
done
```

### Audit All and Save Results

```bash
# Master node
bash Level_1_Master_Node/*_audit.sh | tee results/master_audit.txt

# Worker node
bash Level_1_Worker_Node/*_audit.sh | tee results/worker_audit.txt

# All
bash Level_*/*_audit.sh | tee results/all_audits.txt
```

### Generate Report

```bash
# Count pass/fail
echo "PASSED:"
grep -l "\[+\] PASS" results/*.txt | wc -l

echo "FAILED:"
grep -l "\[-\] FAIL" results/*.txt | wc -l

echo "MANUAL:"
grep -l "\[!\] MANUAL" results/*.txt | wc -l
```

---

## Integration with CI/CD

### Jenkins Pipeline

```groovy
pipeline {
  stages {
    stage('Audit') {
      steps {
        sh 'bash Level_1_Master_Node/*_audit.sh'
      }
    }
    stage('Remediate') {
      steps {
        sh 'sudo bash Level_1_Master_Node/*_remediate.sh'
      }
    }
    stage('Verify') {
      steps {
        sh 'bash Level_1_Master_Node/*_audit.sh'
      }
    }
  }
}
```

### Kubernetes Job

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: cis-hardening
spec:
  template:
    spec:
      containers:
      - name: cis-runner
        image: cis-hardening:latest
        command: ["bash", "-c", "python3 cis_k8s_unified.py"]
      restartPolicy: Never
```

---

## Advanced Features

### Custom Logging

```bash
# Detailed logging
bash -x Level_1_Master_Node/1.1.1_audit.sh 2>&1 | tee debug.log

# Parse logs
grep "ERROR" debug.log
grep "WARNING" debug.log
grep "SUCCESS" debug.log
```

### Dry Run Mode

```bash
# Enable dry run in config
# Set "dry_run": true in config/cis_config.json

# Or via environment
export DRY_RUN="true"
python3 cis_k8s_unified.py
```

### Health Monitoring

```bash
# Check cluster health
python3 cis_k8s_unified.py
# Select: "4) Health Check"

# Manual health check
kubectl get nodes
kubectl get pods -n kube-system
```

---

## Performance Tips

1. **Run audits in parallel** - Non-destructive operations
2. **Run remediation sequentially** - To avoid race conditions
3. **Use dry run first** - To preview changes
4. **Monitor logs in separate window** - Watch journalctl
5. **Disable wait_for_api** if not needed - Speeds up remediation

---

## Security Best Practices

1. ✅ **Always backup** before remediation
2. ✅ **Test on non-production first**
3. ✅ **Use version control** for configs
4. ✅ **Review changes** before applying
5. ✅ **Monitor cluster** after remediation
6. ✅ **Keep audit logs** for compliance

---

