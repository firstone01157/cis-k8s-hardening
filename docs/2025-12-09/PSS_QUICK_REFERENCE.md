# PSS Audit Scripts - Quick Reference & Examples

## TL;DR

All CIS 5.2.x PSS audit scripts now pass if **ANY** of these labels exist on each namespace:
```
pod-security.kubernetes.io/enforce=restricted|baseline
pod-security.kubernetes.io/warn=restricted|baseline
pod-security.kubernetes.io/audit=restricted|baseline
```

System namespaces (`kube-system`, `kube-public`) are excluded.

## Running the Audits

### Single Audit
```bash
bash Level_1_Master_Node/5.2.1_audit.sh
```

### Run All PSS Audits
```bash
cd Level_1_Master_Node
for f in 5.2.{1,2,3,4,5,6,8,10,11,12}_audit.sh; do
    echo "Running $f..."
    bash "$f"
    echo "Exit code: $?"
    echo ""
done
```

### Check Current Labels
```bash
# View all namespace labels
kubectl get ns -o json | jq '.items[] | {name: .metadata.name, labels: .metadata.labels}'

# Check specific namespace
kubectl get ns default --show-labels

# Count namespaces with PSS labels
kubectl get ns -o json | jq '.items[] | select(.metadata.labels["pod-security.kubernetes.io/enforce"] or .metadata.labels["pod-security.kubernetes.io/warn"] or .metadata.labels["pod-security.kubernetes.io/audit"]) | .metadata.name' | wc -l
```

## Setting Labels

### Enforce Mode (Strict - Blocks Violations)
```bash
kubectl label namespace mynamespace \
  pod-security.kubernetes.io/enforce=restricted \
  --overwrite
```

### Warn Mode (Advisory - Shows Warnings)
```bash
kubectl label namespace mynamespace \
  pod-security.kubernetes.io/warn=restricted \
  --overwrite
```

### Audit Mode (Logging - Audit Events)
```bash
kubectl label namespace mynamespace \
  pod-security.kubernetes.io/audit=baseline \
  --overwrite
```

### Set All Three (Recommended for Gradual Migration)
```bash
kubectl label namespace mynamespace \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/audit=restricted \
  --overwrite
```

## Expected Output - PASS

When all namespaces have at least one PSS label:
```
[INFO] Starting check for 5.2.1...
[CMD] Executing: kubectl get ns -o json
[CMD] Executing: jq filter for namespaces without any PSS label (enforce/warn/audit)
[INFO] Check Passed
- Audit Result:
  [+] PASS
  - Check Passed: All non-system namespaces have PSS labels (enforce/warn/audit)
```
Exit code: 0

## Expected Output - FAIL

When namespaces are missing all PSS labels:
```
[INFO] Starting check for 5.2.1...
[CMD] Executing: kubectl get ns -o json
[CMD] Executing: jq filter for namespaces without any PSS label (enforce/warn/audit)
[INFO] Check Failed
- Audit Result:
  [-] FAIL
  - Reason(s) for audit failure:
  - Check Failed: The following namespaces are missing PSS labels (enforce/warn/audit):
  - default
  - logging
  - monitoring
```
Exit code: 1

## Remediation Script

When audit fails, use the corresponding remediation script:
```bash
bash Level_1_Master_Node/5.2.1_remediate.sh
```

Remediation scripts will label all namespaces with the appropriate PSS level.

## Policy Levels Explained

### Restricted (Most Secure)
```bash
pod-security.kubernetes.io/enforce=restricted
```
**Blocks**:
- Privileged containers
- HostPID, HostIPC, HostNetwork
- Root containers (usually)
- Elevated capabilities
- Volume access to sensitive parts of host

**Use for**: Production, sensitive workloads, security-first environments

### Baseline (Reasonable Default)
```bash
pod-security.kubernetes.io/enforce=baseline
```
**Blocks**:
- Only explicitly forbidden behaviors
- Privileged containers (generally)
- Access to host namespaces
- Linux capabilities escalation

**Use for**: Most user workloads, standard applications

### Unrestricted (Legacy)
```bash
pod-security.kubernetes.io/enforce=unrestricted
```
**Blocks**: Nothing
**Use for**: Unavoidable legacy workloads, temporary migrations

## Safety Mode - Graduated Migration Strategy

### Week 1: Audit with Warnings
Set everything to `warn=baseline` to see what would fail:
```bash
kubectl label ns --all \
  pod-security.kubernetes.io/warn=baseline \
  --overwrite
```

Watch logs for warnings:
```bash
kubectl logs -f -n kube-system deployment/admission-controller
```

### Week 2-3: Fix Workloads
Address workloads that show warnings. Update pod specs.

### Week 4: Enable Enforcement
Once workloads are fixed, enable enforcement:
```bash
kubectl label ns --all \
  pod-security.kubernetes.io/enforce=baseline \
  --overwrite
```

### Week 5+: Increase Strictness
Gradually upgrade from `baseline` to `restricted`:
```bash
kubectl label ns --all \
  pod-security.kubernetes.io/enforce=restricted \
  --overwrite
```

## Troubleshooting

### Audits Keep Failing
Check if all namespaces have labels:
```bash
kubectl get ns -o json | jq '.items[] | select(.metadata.labels["pod-security.kubernetes.io/enforce"] == null and .metadata.labels["pod-security.kubernetes.io/warn"] == null and .metadata.labels["pod-security.kubernetes.io/audit"] == null) | .metadata.name'
```

Add missing labels:
```bash
kubectl label ns <namespace> pod-security.kubernetes.io/warn=baseline --overwrite
```

### kubectl or jq Not Available
Install them:
```bash
# On master node
apt-get install -y kubectl jq

# Or via package manager
yum install -y kubectl jq
```

### Permission Denied
Ensure you have cluster-admin rights:
```bash
kubectl auth can-i list namespaces
kubectl auth can-i patch namespaces
```

## Files Included

### Level 1 (Non-System Enforced)
- 5.2.1_audit.sh - Ensure cluster has at least one policy mechanism
- 5.2.2_audit.sh - Minimize admission of privileged containers
- 5.2.3_audit.sh - Minimize host process ID namespace sharing
- 5.2.4_audit.sh - Minimize host IPC namespace sharing
- 5.2.5_audit.sh - Minimize host network namespace sharing
- 5.2.6_audit.sh - Minimize allowPrivilegeEscalation admission
- 5.2.8_audit.sh - Minimize SELinux custom options
- 5.2.10_audit.sh - Minimize added Linux capabilities
- 5.2.11_audit.sh - Minimize SecurityContext changes
- 5.2.12_audit.sh - Minimize /proc writable admission

### Level 2 (Pod-Level Checks)
- 5.2.7_audit.sh - Minimize root containers (checks runAsNonRoot)
- 5.2.9_audit.sh - Minimize added capabilities (checks capabilities.add)

## One-Liner Test

Check if all non-system namespaces have PSS labels:
```bash
kubectl get ns -o json | jq -r '.items[] | select(.metadata.name != "kube-system" and .metadata.name != "kube-public") | select((.metadata.labels["pod-security.kubernetes.io/enforce"] == null) and (.metadata.labels["pod-security.kubernetes.io/warn"] == null) and (.metadata.labels["pod-security.kubernetes.io/audit"] == null)) | .metadata.name' | wc -l
```

If output is `0` → All namespaces compliant ✅
If output is `> 0` → Missing namespaces ❌

---

**For detailed information**, see `PSS_AUDIT_SCRIPTS_STATUS.md`
