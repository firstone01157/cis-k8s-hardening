# CIS Configuration v2.0 - Quick Reference Guide

## 📋 What Changed?

### ✅ Issue 1: Duplicate Logic
- **Removed:** `checks_config` section (deprecated)
- **Kept:** `remediation_config.checks` (authoritative source)
- **Result:** Single source of truth for all 90 checks

### ✅ Issue 2: 5.3.2 Conflict
- **Before:** Different values in two places (enabled=true vs enabled=false)
- **After:** Unified as `enabled: false` (Safety First Strategy)
- **Reason:** Prevent breaking cluster traffic with premature NetworkPolicy enforcement

### ✅ Issue 3: Missing Master Node Flags
- **Added 46 checks:**
  - API Server Flags: 30 checks (1.2.1 → 1.2.30)
  - Controller Manager: 7 checks (1.3.1 → 1.3.7)
  - Scheduler: 2 checks (1.4.1 → 1.4.2)
  - Etcd: 7 checks (2.1 → 2.7)

---

## 📊 Configuration Statistics

```
Total Checks:           90
├─ Enabled:            87
└─ Disabled:            3 (intentional)

By CIS Section:
├─ Section 1 (Manifests/Flags): 60 checks
├─ Section 2 (Etcd):             7 checks
├─ Section 3 (Logging):          2 checks
├─ Section 4 (Kubelet):         18 checks
└─ Section 5 (Policies):         3 checks

Variables Parameters:   46+
├─ API Server:         16 params
├─ Controller Manager:  6 params
├─ Scheduler:          2 params
├─ Etcd:               7 params
└─ Other (paths, perms): 20 params
```

---

## 🔍 Structure Overview

```
cis_config.json (v2.0)
├─ _metadata (version, last_updated, notes)
├─ excluded_rules (1.1.12, 1.2.15, 2.7)
├─ custom_parameters
├─ health_check
├─ logging
├─ variables (DRY - Single Source)
│  ├─ kubernetes_paths
│  ├─ file_permissions
│  ├─ file_ownership
│  ├─ api_server_flags ✨NEW
│  ├─ controller_manager_flags ✨NEW
│  ├─ scheduler_flags ✨NEW
│  ├─ etcd_flags ✨NEW
│  ├─ kubelet_config_params
│  └─ audit_configuration
└─ remediation_config
   ├─ global (backup, dry_run, api settings)
   └─ checks (95 items - AUTHORITATIVE SOURCE)
      ├─ _section_1_1 (File/Directory Permissions)
      ├─ _section_1_2 (API Server Flags) ✨EXPANDED
      ├─ _section_1_3 (Controller Manager) ✨NEW
      ├─ _section_1_4 (Scheduler) ✨NEW
      ├─ _section_2 (Etcd) ✨EXPANDED
      ├─ _section_3 (Logging)
      ├─ _section_4 (Worker Node)
      └─ _section_5 (Policies)
```

---

## 🎯 Check Categories

### Master Node Checks (Section 1-2)

#### L1.1: File & Directory Permissions (21 checks)
- API Server, Controller Manager, Scheduler, Etcd manifests
- Configuration file permissions (600/644)
- Certificate file ownership (root:root)

**Example:**
```json
"1.1.1": {
    "config_file": "/etc/kubernetes/manifests/kube-apiserver.yaml",
    "file_mode": "600",
    "owner": "root:root"
}
```

#### 1.2: API Server Flags (30 checks) ✨NEW
- Authentication & Authorization (--anonymous-auth, --authorization-mode)
- TLS & Encryption (--tls-cert-file, --encryption-provider-config)
- Audit Logging (--audit-log-path, --audit-log-maxage)
- Network Binding (--bind-address, --secure-port)

**Example:**
```json
"1.2.2": {
    "flag": "--authorization-mode",
    "required_value": "Node,RBAC",
    "_required_value_ref": "variables.api_server_flags.authorization_mode"
}
```

#### 1.3: Controller Manager Flags (7 checks) ✨NEW
- Credentials & Accounts (--service-account-private-key-file)
- Pod Garbage Collection (--terminated-pod-gc-threshold)
- Security (--use-service-account-credentials)

#### 1.4: Scheduler Flags (2 checks) ✨NEW
- Profiling & Network (--profiling, --bind-address)

#### 2.x: Etcd Flags (7 checks) ✨EXPANDED
- Certificate Authentication (--client-cert-auth, --peer-client-cert-auth)
- TLS Configuration (--cert-file, --key-file, --peer-cert-file)
- Auto-TLS Disabling (--auto-tls, --peer-auto-tls)

### Worker Node Checks (Section 4)
#### 4.1: Kubelet File Permissions (4 checks)
- Config file permissions (600)
- Service file permissions (644)

#### 4.2: Kubelet Configuration (14 checks)
- Authentication (--anonymous-auth, --authorization-mode)
- Network (--read-only-port, --streaming-connection-idle-timeout)
- Security (--protect-kernel-defaults, --seccomp-default)

### Policy Checks (Section 5)
#### 5.2: Pod Security Standards (1 check)
#### 5.3: Network Policies (1 check) ⚠️ **DISABLED** (Safety First)
#### 5.6: Namespace Policies (1 check)

---

## 🔗 Variables Reference Pattern

All checks reference the `variables` section for DRY (Don't Repeat Yourself):

```json
// Check Definition
"1.2.7": {
    "flag": "--bind-address",
    "required_value": "127.0.0.1",
    "_required_value_ref": "variables.api_server_flags.bind_address"
}

// Variables Definition
"variables": {
    "api_server_flags": {
        "bind_address": "127.0.0.1",
        "_bind_address_comment": "CIS 1.2.7 - Bind to localhost"
    }
}
```

**Benefits:**
- Update once, applies everywhere
- Centralized documentation
- Consistency across checks
- Easy configuration management

---

## ⚙️ Configuration Usage

### Python Integration
```python
import json

with open('cis_config.json') as f:
    config = json.load(f)

# Access checks
checks = config['remediation_config']['checks']
check_1_2_7 = checks['1.2.7']

# Access variables
api_flags = config['variables']['api_server_flags']
bind_addr = api_flags['bind_address']  # "127.0.0.1"
```

### In cis_k8s_unified.py
```python
def get_remediation_config_for_check(self, check_id):
    # Single authoritative source
    return self.remediation_config['checks'].get(check_id, {})

def load_config(self):
    # Load variables for DRY principles
    self.variables = config['variables']
```

---

## 🚀 Deployment Checklist

- [ ] Backup current `cis_config.json`
- [ ] Replace with new v2.0 configuration
- [ ] Validate JSON syntax: `python3 -m json.tool cis_config.json`
- [ ] Test audit mode: `python3 cis_k8s_unified.py` (Audit)
- [ ] Verify all 90 checks load
- [ ] Review disabled checks (1.2.15, 2.7, 5.3.2)
- [ ] Adjust `excluded_rules` if needed for your environment
- [ ] Document any custom `environment_overrides`
- [ ] Run in production

---

## 🔒 Safety First Strategy

### 5.3.2 - NetworkPolicies (⚠️ DISABLED by default)

**Status:** `enabled: false` (Safety First)

**Rationale:**
- NetworkPolicies can block legitimate traffic if misconfigured
- Breaking cluster connectivity is worse than no policies
- Gradual implementation reduces risk

**When to Enable:**
1. Implement allow-all policy first (current)
2. Test for 2-4 weeks
3. Document all expected traffic flows
4. Create deny-all policy with explicit allows
5. Set `enabled: true` in production after validation

**Configuration:**
```json
"5.3.2": {
    "enabled": false,
    "reason": "Safety First Strategy - Allow-all prevents breaking traffic",
    "remediation_note": "Enable only after proper network segmentation planning"
}
```

---

## 📝 Disabled Checks

| Check | Status | Reason |
|-------|--------|--------|
| **1.2.15** | IGNORED | Environment-specific (service account lookup) |
| **2.7** | RISK_ACCEPTED | Etcd CA file (acceptable in your environment) |
| **5.3.2** | SAFETY_FIRST | NetworkPolicies (default: allow-all) |

To re-enable:
```json
"check_id": {
    "enabled": true,
    ...
}
```

---

## 📞 Support & Questions

### Common Questions

**Q: Why is 5.3.2 disabled?**  
A: Safety First - Prevent breaking cluster traffic. Enable after proper network segmentation testing.

**Q: How do I update a required value?**  
A: Update in `variables` section, it applies to all checks using `_required_value_ref`.

**Q: Can I disable a check?**  
A: Set `"enabled": false` for that check in `remediation_config.checks`.

**Q: How many checks are there?**  
A: 90 total (87 enabled, 3 intentionally disabled).

### Validation
```bash
# Verify JSON syntax
python3 -m json.tool cis_config.json

# Count checks
python3 -c "import json; c=json.load(open('cis_config.json')); \
  checks=[k for k in c['remediation_config']['checks'] if not k.startswith('_')]; \
  print(f'Total: {len(checks)}')"
```

---

## 📚 File Structure

```
/home/first/Project/cis-k8s-hardening/
├─ cis_config.json                      (v2.0 - UPDATED)
├─ cis_k8s_unified.py                   (Compatible)
├─ CONFIG_CONSOLIDATION_SUMMARY.md      (Detailed documentation)
├─ CONFIG_QUICK_REFERENCE.md            (This file)
└─ ... (audit/remediate scripts)
```

---

**Version:** 2.0  
**Status:** ✅ Production Ready  
**Last Updated:** 2025-12-09  
**Compatibility:** cis_k8s_unified.py (Latest)
