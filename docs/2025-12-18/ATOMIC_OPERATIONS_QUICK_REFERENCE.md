# Atomic Operations - Quick Reference Card

## 🔧 Two Core Functions

### 1. update_manifest_safely()
**Atomically modify YAML manifests without corruption**

```python
result = runner.update_manifest_safely(
    filepath="/etc/kubernetes/manifests/kube-apiserver.yaml",
    key="--audit-policy-file=",
    value="/etc/kubernetes/audit-policy.yaml"
)

# Returns: {'success': bool, 'backup_path': str, 'changes_made': int, ...}
```

**When to use:** Direct file modifications where you control health checking separately

---

### 2. apply_remediation_with_health_gate()
**Apply remediation with automatic health checks and rollback**

```python
result = runner.apply_remediation_with_health_gate(
    filepath="/etc/kubernetes/manifests/kube-apiserver.yaml",
    key="--audit-policy-file=",
    value="/etc/kubernetes/audit-policy.yaml",
    check_id="1.2.5",
    script_dict={"path": "./Level_1_Master_Node/1.2.5_remediate.sh"},
    timeout=60
)

# Returns: {'success': bool, 'status': str, 'reason': str, ...}
```

**When to use:** Full remediation with automatic rollback on failure (RECOMMENDED)

---

## 📊 Status Flow

```
BACKUP → APPLY → HEALTH GATE → AUDIT
                      ↓
                  UNHEALTHY?
                      ↓
                  ROLLBACK ← ← ← ← FAIL
                      
                      ↓
                  HEALTHY?
                      ↓
                  RUN AUDIT
                      ↓
                  PASS? → SUCCESS
                      ↓
                    FAIL
                      ↓
                  ROLLBACK ← ← ← FAIL
```

---

## ✅ Success Codes

| Status | Meaning |
|--------|---------|
| `FIXED` | ✅ All checks passed |
| `REMEDIATION_FAILED_ROLLED_BACK` | ⚠️ Failed but recovered |
| `REMEDIATION_FAILED_ROLLBACK_FAILED` | 🔴 CRITICAL - manual fix needed |
| `REMEDIATION_FAILED` | ❌ Modification failed |

---

## 🚨 Failure Scenarios

### Scenario 1: Modification Failed
```
→ Backup intact, original unchanged
→ No cluster impact
→ Safe to retry
```

### Scenario 2: Health Check Timeout
```
→ File modified, API unresponsive
→ Automatic rollback triggered
→ Cluster recovers automatically
→ Log: [CRITICAL] API Server failed to restart. Rolling back...
```

### Scenario 3: Audit Verification Failed
```
→ API healthy, config invalid
→ Automatic rollback triggered
→ Cluster recovers automatically
→ Log: Audit verification failed. Rolled back.
```

### Scenario 4: CRITICAL - Rollback Failed
```
→ Config broken AND can't rollback
→ EMERGENCY STOP triggered
→ MANUAL INTERVENTION REQUIRED
→ Recovery: sudo cp backup /etc/kubernetes/manifests/kube-apiserver.yaml
```

---

## 📝 Common Use Cases

### Modify API Server Audit Policy
```python
result = runner.apply_remediation_with_health_gate(
    filepath="/etc/kubernetes/manifests/kube-apiserver.yaml",
    key="--audit-policy-file=",
    value="/etc/kubernetes/audit-policy.yaml",
    check_id="1.2.5",
    script_dict={"path": "./Level_1_Master_Node/1.2.5_remediate.sh"}
)
```

### Set Audit Log Parameters
```python
result = runner.apply_remediation_with_health_gate(
    filepath="/etc/kubernetes/manifests/kube-apiserver.yaml",
    key="--audit-log-maxage=",
    value="30",
    check_id="1.2.26",
    script_dict={"path": "./Level_1_Master_Node/1.2.26_remediate.sh"}
)
```

### Batch Multiple Changes
```python
for key, value, check_id in modifications:
    result = runner.apply_remediation_with_health_gate(
        filepath="/etc/kubernetes/manifests/kube-apiserver.yaml",
        key=key,
        value=value,
        check_id=check_id,
        script_dict={"path": f"./Level_1_Master_Node/{check_id}_remediate.sh"}
    )
    if not result['success']:
        break  # Stop on first failure
```

---

## 🛠️ Manual Recovery

### If Remediation Fails
```bash
# 1. Find the backup
ls -la /etc/kubernetes/manifests/kube-apiserver.yaml.bak_*

# 2. Restore it
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml.bak_20251218_123456 \
        /etc/kubernetes/manifests/kube-apiserver.yaml

# 3. Restart Kubelet
sudo systemctl restart kubelet

# 4. Verify
kubectl get nodes
kubectl get pods -n kube-system | grep api
```

---

## 📊 Key Features

| Feature | Benefit |
|---------|---------|
| **Atomic Operations** | No half-written files corrupting cluster |
| **Automatic Backup** | Always have a rollback point |
| **Health Gating** | API must be responsive before proceeding |
| **Audit Verification** | Confirm config actually fixes the issue |
| **Auto Rollback** | Recover automatically on any failure |
| **Logging** | Full audit trail in cis_runner.log |
| **Error Handling** | Comprehensive exception handling |
| **Thread-Safe** | Safe to use in concurrent contexts |

---

## 🔍 Checking Results

```python
result = runner.apply_remediation_with_health_gate(...)

# Check if successful
if result['success']:
    print(f"✓ {result['reason']}")
    print(f"  Audit verified: {result['audit_verified']}")
else:
    print(f"✗ {result['reason']}")
    if result['backup_path']:
        print(f"  Backup: {result['backup_path']}")

# Access all fields
print(result['status'])           # FIXED, REMEDIATION_FAILED, etc.
print(result['backup_path'])      # Where backup was saved
print(result['audit_verified'])   # True if audit check passed
```

---

## 📋 Checklist Before Running

- [ ] Cluster is healthy: `kubectl get nodes`
- [ ] API server is responding: `kubectl get pods -n kube-system`
- [ ] Have manual recovery procedure handy (see above)
- [ ] Backup script paths are correct
- [ ] Running with appropriate privileges (sudo if needed)

---

## 🚀 Getting Started

### 1. Import the Runner
```python
from cis_k8s_unified import CISUnifiedRunner
runner = CISUnifiedRunner(verbose=1)
```

### 2. Apply Remediation
```python
result = runner.apply_remediation_with_health_gate(
    filepath="/etc/kubernetes/manifests/kube-apiserver.yaml",
    key="--audit-policy-file=",
    value="/etc/kubernetes/audit-policy.yaml",
    check_id="1.2.5",
    script_dict={"path": "./Level_1_Master_Node/1.2.5_remediate.sh"}
)
```

### 3. Check Result
```python
if result['success']:
    print("✓ Remediation successful and verified")
else:
    print(f"✗ Failed: {result['reason']}")
```

---

## 📚 Full Documentation

- **ATOMIC_OPERATIONS_GUIDE.md** - Complete algorithm & API reference
- **ATOMIC_OPERATIONS_EXAMPLES.md** - 10 real-world code examples
- **ATOMIC_OPERATIONS_IMPLEMENTATION.md** - Implementation summary

---

## ⚡ Key Guarantees

✅ **File Integrity** - Uses `os.replace()` for atomic operations  
✅ **Backup Safety** - Auto backup before any modification  
✅ **Rollback Capability** - Automatic on health/audit failure  
✅ **Logging** - Full activity trail in cis_runner.log  
✅ **No Corruption** - Kubelet never sees half-written files  
✅ **Production Ready** - Comprehensive error handling  

---

## 🆘 Troubleshooting

### "API Server failed to restart"
→ Check logs: `journalctl -u kubelet -n 50`  
→ Manual recovery available in backup  

### "Audit verification failed"
→ Config doesn't meet CIS requirement  
→ Check output of audit script manually  
→ Automatic rollback already performed  

### "Rollback failed"
→ CRITICAL - manual intervention needed  
→ See recovery section above  

---

## 📞 Support Resources

1. **ATOMIC_OPERATIONS_GUIDE.md** - Comprehensive reference
2. **ATOMIC_OPERATIONS_EXAMPLES.md** - Real-world examples  
3. Code comments in `cis_k8s_unified.py` - Inline documentation
4. Logs: `grep REMEDIATION cis_runner.log` - Activity trail

---

**Version:** 1.0  
**Last Updated:** December 18, 2025  
**Status:** Production Ready ✅
