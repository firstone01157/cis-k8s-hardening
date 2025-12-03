# CIS Benchmark Manual Check Conversion Analysis

## Status: 41 Manual Checks to Automate

### Sections Affected:
1. **Section 1** (Etcd & API Server): ~9 checks
2. **Section 2** (Etcd): ~1 check  
3. **Section 3** (Control Plane): ~4 checks
4. **Section 4** (Worker Kubelet): ~12 checks
5. **Section 5** (Policies/RBAC): 13 already automated, ~15 more needed

---

## Strategy

### Phase 1: Section 5 (Policies/RBAC/Network) - PRIORITY
These are the most automatable using kubectl+jq without system file access.

**Status**: Some already converted (5.1.1, 5.2.2, 5.2.3, etc.)
**Remaining**:
- Section 5.2: Privilege Escalation checks (5.2.6, 5.2.7, 5.2.9 if missing)
- Section 5.3: Network Policy enforcement (5.3.2+)
- Section 5.4: RBAC additional checks
- Section 5.5-5.6: Namespace isolation checks

### Phase 2: Section 4 (Worker Node) - MEDIUM
Worker node checks mostly require local file/process inspection.
**Automatable ones**:
- Pod-level checks can be done via kubectl from master
- kubelet config inspection (if exported as ConfigMap)

**Requires kubeconfig/local access**:
- kubelet service file permissions
- proxy kubeconfig permissions  
- sysctl configurations

### Phase 3: Sections 1, 2, 3 (Control Plane) - LOWER PRIORITY
These require inspection of:
- Static pod manifests
- API server flags
- Service files
- Configuration files

**Partially automatable** via:
- `kubectl get pod -n kube-system kube-apiserver-* -o yaml`
- Checking node status and API responses

---

## Conversion Approach

For each manual check, we will:

1. **Identify the check intent** (what is the security goal?)
2. **Determine automation method**:
   - ✅ kubectl + jq (cluster-scoped resources)
   - ✅ kubectl + system audit (if exposed via API)
   - ⚠️ Partial automation (with warnings)
   - ❌ Requires manual + advisory output

3. **Output format**:
   ```
   [PASS] - When no violations detected
   [FAIL] - With list of offending resources
   [WARNING] - When partial check or requires validation
   ```

---

## Quick Wins (Section 5 - Priority)

### 5.1.x - RBAC (mostly done)
- ✅ 5.1.1: cluster-admin scope
- ✅ 5.1.2: Minimize secrets access
- ✅ 5.1.3+: Various role restrictions

### 5.2.x - Pod Security
- ✅ 5.2.2: Privileged containers
- ✅ 5.2.3: hostPID
- ✅ 5.2.4: hostIPC
- ✅ 5.2.5: hostNetwork
- ✅ 5.2.6: allowPrivilegeEscalation
- ✅ 5.2.8: NET_RAW capability
- ✅ 5.2.10: Windows HostProcess
- ✅ 5.2.11: hostPath volumes
- ✅ 5.2.12: hostPorts
- 🔄 5.2.7: Read-only filesystem (if missing)
- 🔄 5.2.9: Seccomp/AppArmor (if missing)

### 5.3.x - Network Policies
- ✅ 5.3.1: NetworkPolicy support check
- 🔄 5.3.2: NetworkPolicy per namespace (need to create)

### 5.4.x - Additional RBAC
- 🔄 Need to review which are still manual

### 5.6.x - Namespace Isolation
- ✅ 5.6.1: Administrative boundaries (custom namespaces)

---

## Implementation Order

1. Create missing 5.3.2 (NetworkPolicy per namespace)
2. Create/verify 5.2.7, 5.2.9 (additional pod security)
3. Create/verify 5.4.x series (RBAC)
4. Create enhanced 4.x scripts for pod-level checks
5. Create Section 1-3 advisory scripts with best-effort automation

---

## Output Format Standard

All converted scripts will follow:

```bash
#!/bin/bash
# CIS Benchmark: X.Y.Z
# Title: [Title] (Automated)
# Level: • Level [1/2] - [Master/Worker] Node

audit_rule() {
    unset a_output
    unset a_output2
    
    # kubectl+jq query
    # Populate a_output for PASS
    # Populate a_output2 for FAIL
    
    if [ "${#a_output2[@]}" -le 0 ]; then
        printf '%s\n' "" "- Audit Result:" "  [+] PASS" "${a_output[@]}"
        return 0
    else
        printf '%s\n' "" "- Audit Result:" "  [-] FAIL" " - Reason(s) for audit failure:" "${a_output2[@]}"
        return 1
    fi
}

audit_rule
exit $?
```

---

## Next Steps

1. Audit all 41 manual checks
2. Categorize by automation feasibility  
3. Create conversion scripts for each category
4. Test against sample cluster
5. Update cis_k8s_unified.py to recognize all as automated
