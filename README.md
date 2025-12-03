# CIS Kubernetes Hardening - Complete Guide

> **Comprehensive Kubernetes Security Hardening Framework based on CIS Kubernetes Benchmark v1.12.0**

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Project Structure](#project-structure)
4. [Installation](#installation)
5. [Usage Guide](#usage-guide)
6. [Available Checks](#available-checks)
7. [Configuration](#configuration)
8. [Troubleshooting](#troubleshooting)
9. [Advanced Features](#advanced-features)

---

## 🎯 Overview

This project provides an automated framework for auditing and remediating Kubernetes cluster security based on the **CIS Kubernetes Benchmark v1.12.0**. It includes:

✅ **Audit Scripts** - Detect security issues  
✅ **Remediation Scripts** - Automatically fix security issues  
✅ **Python Tools** - Advanced configuration management  
✅ **Smart Checks** - Understand Kubeadm defaults vs custom configs  
✅ **Two Compliance Levels** - Level 1 (basic) and Level 2 (advanced)  

### Supported Components
- **Master Node**: API Server, etcd, Controller Manager, Scheduler
- **Worker Node**: Kubelet, kube-proxy, Container Runtime
- **Network Policies**: CNI configuration, Pod security policies
- **RBAC**: Role-based access control configuration

---

## 🚀 Quick Start

### For Master Node (CIS 1.x & 2.x)

```bash
# Run all master checks (audit)
bash master_run_all.sh

# Or use Python runner
python3 master_runner.py

# View detailed results
cat results/audit_results.txt
```

### For Worker Node (CIS 4.x & 5.x)

```bash
# Audit specific worker check
bash Level_1_Worker_Node/4.1.1_audit.sh

# Apply remediation
sudo bash Level_1_Worker_Node/4.1.1_remediate.sh

# Verify fix
bash Level_1_Worker_Node/4.1.1_audit.sh
```

### Kubelet Hardening

```bash
# Interactive kubelet hardening
python3 harden_kubelet.py

# Quick start guide
bash harden_kubelet_quick_start.sh
```

---

## 📁 Project Structure

```
cis-k8s-hardening/
│
├── 🔴 ROOT (Main Executables)
│   ├── harden_kubelet.py              ← Kubelet hardening tool
│   ├── master_runner.py               ← Master node runner
│   ├── worker_recovery.py             ← Worker recovery tool
│   ├── master_run_all.sh              ← Run all master checks
│   ├── safe_audit_remediation.sh      ← Safe audit/remediation
│   └── PROJECT_STRUCTURE.md           ← Structure guide
│
├── 📁 Level_1_Master_Node/            ← CIS 1.x & 2.x checks
│   ├── 1.1.1_audit.sh                 ← CIS 1.1.1 audit
│   ├── 1.1.1_remediate.sh             ← CIS 1.1.1 remediation
│   ├── 1.2.1_audit.sh                 ← CIS 1.2.1 audit
│   ├── 1.2.1_remediate.sh             ← CIS 1.2.1 remediation
│   └── ... (20+ checks)
│
├── 📁 Level_1_Worker_Node/            ← CIS 4.x & 5.x checks
│   ├── 4.1.1_audit.sh                 ← Kubelet security
│   ├── 4.1.1_remediate.sh
│   ├── 4.2.1_audit.sh                 ← Kubelet config
│   ├── 4.2.1_remediate.sh
│   ├── 5.1.1_audit.sh                 ← Pod security
│   ├── 5.1.1_remediate.sh
│   ├── kubelet_helpers.sh              ← Helper functions
│   ├── SMART_REMEDIATION_GUIDE.md
│   └── ... (20+ checks)
│
├── 📁 Level_2_Master_Node/            ← Level 2 master checks
│   └── ... (advanced checks)
│
├── 📁 Level_2_Worker_Node/            ← Level 2 worker checks
│   └── ... (advanced checks)
│
├── 📁 tools/                          ← Python tools
│   ├── harden_kubelet.py              ← Main kubelet tool
│   ├── kubelet_config_manager.py      ← Config manager
│   ├── harden_apiserver_audit.py      ← API server audit
│   ├── enhance_audit_scripts.py       ← Script enhancement
│   ├── bulk_update_debug_info.py      ← Bulk updates
│   └── Unit Test/                     ← Unit tests
│
├── 📁 scripts/                        ← Utility scripts
│   ├── master_audit_only.sh           ← Audit only
│   ├── master_remediate_only.sh       ← Remediate only
│   ├── setup_audit_logging.sh         ← Logging setup
│   ├── diagnose_audit_issues.sh       ← Diagnostics
│   └── ... (helper scripts)
│
├── 📁 docs/                           ← Documentation
│   ├── QUICK_REFERENCE.md             ← Quick ref
│   ├── USAGE_GUIDE.md                 ← Detailed guide
│   ├── CONFIG_DRIVEN_INTEGRATION_GUIDE.md
│   ├── IMPLEMENTATION_SUMMARY.md
│   ├── PROTECT_KERNEL_DEFAULTS_FIX.md
│   ├── CIS_Kubernetes_Benchmark_V1.12.0_PDF.csv
│   └── ... (20+ docs)
│
├── 📁 config/                         ← Configuration
│   ├── cis_config.json                ← Main config
│   ├── cis_config_example.json        ← Example
│   ├── Job.YAML                       ← K8s resource
│   └── Dockerfile
│
├── 📁 logs/                           ← Execution logs
├── 📁 results/                        ← Audit results
├── 📁 temp/                           ← Temporary files
│
├── .git/                              ← Git repo
├── .gitignore
└── README.md                          ← This file
```

---

## 🔧 Installation

### Prerequisites

```bash
# Required
- Linux (CentOS 7+, Ubuntu 18.04+)
- Bash 4.0+
- Python 3.6+
- kubectl (for Kubernetes interaction)
- sudo/root access

# Optional
- jq (JSON processing)
- yamllint (YAML validation)
- git (version control)
```

### Setup

#### 1. Clone/Download Project
```bash
# Clone from git
git clone <repo-url> cis-k8s-hardening
cd cis-k8s-hardening

# Or download tar
tar xzf cis-k8s-hardening.tar.gz
cd cis-k8s-hardening
```

#### 2. Make Scripts Executable
```bash
chmod +x *.sh
chmod +x scripts/*.sh
chmod +x Level_*_*/[0-9]*.sh
chmod +x tools/*.py
```

#### 3. Install Python Dependencies (Optional)
```bash
pip3 install pyyaml
# or
pip3 install -r requirements.txt
```

#### 4. Copy to Worker/Master Nodes
```bash
# Copy to master node
scp -r cis-k8s-hardening master@<master-ip>:/opt/

# Copy to worker nodes
for worker in <worker-ips>; do
  scp -r cis-k8s-hardening node@$worker:/opt/
done
```

---

## 📖 Usage Guide

### Mode 1: Audit Only (Detect Issues)

#### Single Check
```bash
# Audit CIS 1.1.1 on master
bash Level_1_Master_Node/1.1.1_audit.sh

# Example output:
# - Audit Result:
#   [+] PASS
#    - Check Passed: API server auth mode is Webhook
```

#### Multiple Checks
```bash
# Audit all master checks
bash master_audit_only.sh

# Audit specific level
bash Level_1_Master_Node/*_audit.sh
```

### Mode 2: Remediation (Fix Issues)

#### Single Remediation
```bash
# Fix CIS 1.1.1 issue
sudo bash Level_1_Master_Node/1.1.1_remediate.sh

# Example output:
# - Remediation Result:
#   [+] FIXED
#    - Set API server auth mode to Webhook
```

#### Safe Mode (Audit + Show Fix)
```bash
# See what would be fixed without applying
bash safe_audit_remediation.sh
```

### Mode 3: Full Workflow

```bash
# 1. Audit to see issues
bash master_run_all.sh

# 2. Review results
cat results/audit_results.txt

# 3. Apply remediation
sudo bash master_remediate_only.sh

# 4. Verify fixes
bash master_run_all.sh
```

### Advanced: Kubelet Configuration

```bash
# Interactive kubelet hardening
python3 harden_kubelet.py

# Output:
# ✓ Loading existing config
# ✓ Extracting critical values
# ✓ Hardening configuration
# ✓ Writing new config
# ✓ Verifying changes
# ✓ Restarting kubelet
```

#### Configuration via Environment Variables
```bash
# Set kubelet security parameters
export CONFIG_ANONYMOUS_AUTH="false"
export CONFIG_WEBHOOK_AUTH="true"
export CONFIG_MAKE_IPTABLES_UTIL_CHAINS="true"
export CONFIG_PROTECT_KERNEL_DEFAULTS="false"  # Safe default

python3 harden_kubelet.py
```

---

## ✅ Available Checks

### Level 1 - Master Node (CIS 1.x & 2.x)

| Check | Description | Status |
|-------|-------------|--------|
| **1.1** | API Server | ✓ 10+ checks |
| **1.2** | API Server Auth | ✓ 8+ checks |
| **1.3** | API Server Config | ✓ 6+ checks |
| **1.4** | Controller Manager | ✓ 5+ checks |
| **1.5** | Scheduler | ✓ 3+ checks |
| **2.1** | etcd | ✓ 7+ checks |
| **2.2** | etcd Security | ✓ 5+ checks |

**Total: 40+ master node checks**

### Level 1 - Worker Node (CIS 4.x & 5.x)

| Check | Description | Status |
|-------|-------------|--------|
| **4.1** | Kubelet Config | ✓ 10+ checks |
| **4.2** | Kubelet Security | ✓ 14+ checks |
| **4.3** | Container Runtime | ✓ 2+ checks |
| **5.1** | RBAC | ✓ 3+ checks |
| **5.2** | Pod Security | ✓ 6+ checks |

**Total: 35+ worker node checks**

### Smart Checks (4.1.3, 4.1.4, 4.1.7, 4.1.8)

These checks are "SMART" because they:
- ✅ **PASS if not configured** (secure Kubeadm default)
- ✅ **FIX if needed** (automatically apply remediation)
- ✅ **PRESERVE existing** (respect manual config)

Example: `4.1.3_remediate.sh`
```
IF kube-proxy --kubeconfig NOT set
    → PASS (using in-cluster config, which is secure)
ELSE IF file doesn't exist
    → FAIL (configuration error)
ELSE IF permissions wrong
    → FIX (chmod 600)
```

---

## ⚙️ Configuration

### Main Configuration File

**File:** `config/cis_config.json`

```json
{
  "master_node": {
    "api_server_auth_mode": "Webhook",
    "api_server_insecure_port": 0,
    "api_server_secure_port": 6443,
    "etcd_client_cert_auth": true,
    "controller_manager_feature_gates": ["RotateKubeletServerCertificate=true"]
  },
  "worker_node": {
    "kubelet_anonymous_auth": false,
    "kubelet_webhook_auth": true,
    "kubelet_webhook_authz": true,
    "kubelet_make_iptables_util_chains": true,
    "kubelet_protect_kernel_defaults": false,
    "kubelet_event_record_qps": 5
  }
}
```

### Environment Variables

Control behavior via environment variables:

```bash
# Master Node
export AUDIT_ONLY="true"              # Don't apply fixes
export VERBOSE="true"                 # Detailed output
export DRY_RUN="true"                 # Show what would be done

# Worker Node (Kubelet)
export CONFIG_ANONYMOUS_AUTH="false"
export CONFIG_WEBHOOK_AUTH="true"
export CONFIG_PROTECT_KERNEL_DEFAULTS="false"
export CONFIG_ROTATE_CERTIFICATES="true"
```

---

## 🔍 Troubleshooting

### Issue: Permission Denied

```bash
# Fix: Run with sudo
sudo bash 1.1.1_remediate.sh

# Or set SUDO_USER if running via sudo
sudo -u root bash script.sh
```

### Issue: Script Not Found

```bash
# Ensure scripts are executable
chmod +x *.sh
chmod +x Level_*_*/*.sh
chmod +x scripts/*.sh

# Verify paths
pwd  # Should be in cis-k8s-hardening/
ls -l 1.1.1_audit.sh  # Should exist
```

### Issue: Config File Not Found

```bash
# Check kubelet config location
ps aux | grep kubelet | grep config

# Common locations:
# - /var/lib/kubelet/config.yaml
# - /etc/kubernetes/kubelet.conf
# - /etc/kubernetes/kubelet-kubeadm.conf
```

### Issue: Remediation Failed

```bash
# Check logs
tail -f logs/*.log

# Run in debug mode
bash -x Level_1_Worker_Node/4.1.1_remediate.sh

# Check permissions
stat /var/lib/kubelet/config.yaml
stat /etc/kubernetes/pki/
```

### Issue: Changes Didn't Apply

```bash
# 1. Check if kubelet restarted
systemctl status kubelet

# 2. Check kubelet logs
journalctl -u kubelet -n 100

# 3. Verify changes persisted
grep "setting_name" /var/lib/kubelet/config.yaml

# 4. Check for backup files
ls -la /var/lib/kubelet/config.yaml*
```

---

## 🎓 Advanced Features

### 1. Kubelet Hardening Tool

**File:** `harden_kubelet.py`

Features:
- ✅ Interactive configuration
- ✅ Automatic backup creation
- ✅ Type-safe YAML handling
- ✅ Preserve cluster-specific settings
- ✅ Atomic updates with verification

```bash
# Run with environment variables
CONFIG_ANONYMOUS_AUTH=false \
CONFIG_WEBHOOK_AUTH=true \
CONFIG_PROTECT_KERNEL_DEFAULTS=false \
python3 harden_kubelet.py

# Or interactive
python3 harden_kubelet.py
# Follow prompts to configure each setting
```

### 2. Batch Operations

```bash
# Remediate all Level 1 checks
for script in Level_1_Master_Node/*_remediate.sh; do
  echo "Running: $script"
  sudo bash "$script"
done

# Audit all and save results
for script in Level_1_*/*_audit.sh; do
  bash "$script" >> results/all_audits.txt
done
```

### 3. Custom Logging

```bash
# Enable detailed logging
bash -x master_run_all.sh 2>&1 | tee logs/detailed.log

# Parse results
grep "\[+\] PASS" logs/detailed.log | wc -l    # Count passes
grep "\[-\] FAIL" logs/detailed.log | wc -l    # Count failures
grep "\[!\]" logs/detailed.log                  # Count warnings
```

### 4. Integration with CI/CD

```bash
# In Jenkinsfile or GitLab CI
script:
  - bash master_run_all.sh
  - bash master_remediate_only.sh
  - bash master_run_all.sh  # Verify

# Or as Kubernetes Job
kubectl apply -f config/Job.YAML
kubectl logs -f job/cis-hardening
```

### 5. Monitoring & Compliance

```bash
# Generate compliance report
bash scripts/generate_compliance_report.sh

# Output includes:
# - Total checks: 75
# - Passed: 70
# - Failed: 2
# - Warnings: 3
# - Compliance Score: 93%
```

---

## 📊 Check Coverage

| Component | Level 1 | Level 2 | Total |
|-----------|---------|---------|-------|
| Master Node | 40 | 15 | 55 |
| Worker Node | 35 | 12 | 47 |
| **Total** | **75** | **27** | **102** |

---

## 🔐 Security Notes

### Important Considerations

1. **Backup First**
   ```bash
   # Always backup before remediation
   cp -r /etc/kubernetes /etc/kubernetes.backup
   cp /var/lib/kubelet/config.yaml /var/lib/kubelet/config.yaml.backup
   ```

2. **Test in Non-Production**
   ```bash
   # Never run directly on production
   # Test in dev/staging first
   ```

3. **Safe Defaults**
   - `protectKernelDefaults=false` by default (won't crash on non-tuned kernels)
   - Use environment variables to enable strict mode only on prepared systems

4. **Verify After Changes**
   ```bash
   # Always verify fixes
   bash Level_1_Worker_Node/4.1.1_audit.sh  # Re-run audit
   ```

---

## 📚 Documentation

Detailed documentation available in `docs/`:

| Document | Purpose |
|----------|---------|
| QUICK_REFERENCE.md | Quick command reference |
| USAGE_GUIDE.md | Detailed usage guide |
| CONFIG_DRIVEN_INTEGRATION_GUIDE.md | Integration guide |
| PROTECT_KERNEL_DEFAULTS_FIX.md | Kernel defaults explanation |
| IMPLEMENTATION_SUMMARY.md | Implementation details |
| SMART_REMEDIATION_GUIDE.md | Smart check guide (4.1.x) |

---

## 🤝 Contributing

To add or improve checks:

1. Create audit script: `X.Y.Z_audit.sh`
2. Create remediation script: `X.Y.Z_remediate.sh`
3. Add helper functions to appropriate `*_helpers.sh`
4. Test both scripts
5. Document in appropriate `docs/` file

---

## 📝 License

This project is provided as-is for security hardening purposes.

---

## 🆘 Support & Feedback

For issues or questions:

1. Check `docs/` for detailed documentation
2. Review log files in `logs/`
3. Run troubleshooting script: `diagnose_audit_issues.sh`
4. Check CIS Benchmark documentation

---

## 🎯 Next Steps

### For First-Time Users

```bash
# 1. Read quick start
cat docs/QUICK_REFERENCE.md

# 2. Run initial audit
bash master_run_all.sh

# 3. Review results
cat results/audit_results.txt

# 4. Plan remediation
# (Check which fixes are needed)

# 5. Apply fixes
sudo bash master_remediate_only.sh

# 6. Verify
bash master_run_all.sh
```

### For Production Deployment

```bash
# 1. Test in staging
cd staging/
bash ../master_run_all.sh
bash ../master_remediate_only.sh
bash ../master_run_all.sh

# 2. Backup production
cp -r /etc/kubernetes /etc/kubernetes.backup.$(date +%s)

# 3. Deploy carefully
cd /opt/cis-k8s-hardening/
sudo bash master_remediate_only.sh

# 4. Monitor
tail -f /var/log/kubernetes/*.log
journalctl -u kubelet -f

# 5. Verify
bash master_run_all.sh
```

---

## 📞 Quick Command Reference

```bash
# Audit
bash Level_1_Master_Node/1.1.1_audit.sh
bash Level_1_Worker_Node/4.1.1_audit.sh

# Remediate
sudo bash Level_1_Master_Node/1.1.1_remediate.sh
sudo bash Level_1_Worker_Node/4.1.1_remediate.sh

# Kubelet Hardening
python3 harden_kubelet.py

# Run All Master Checks
bash master_run_all.sh

# Safe Mode (don't apply fixes)
bash safe_audit_remediation.sh

# Generate Report
bash scripts/generate_compliance_report.sh

# View Logs
tail -f logs/*.log
```

---

**Happy Hardening! 🔒**

For latest updates and documentation, see the project structure and available documentation files.
