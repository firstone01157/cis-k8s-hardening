# CIS 5.3.2 NetworkPolicy - Quick Reference

## TL;DR

```bash
# 1. Check compliance
bash Level_1_Master_Node/5.3.2_audit.sh

# 2. Fix non-compliant namespaces
python3 network_policy_manager.py --remediate

# 3. Verify fixed
bash Level_1_Master_Node/5.3.2_audit.sh
```

---

## One-Liners

### Check Which Namespaces Lack Policies
```bash
for ns in $(kubectl get ns -o name | cut -d'/' -f2); do
  [[ "$ns" =~ ^kube- ]] || [[ "$ns" == "default" ]] && continue
  kubectl get networkpolicy -n "$ns" &>/dev/null || echo "Missing: $ns"
done
```

### Count Policies Per Namespace
```bash
kubectl get networkpolicy --all-namespaces -o json | \
  jq -r '.items[] | .metadata.namespace' | sort | uniq -c
```

### Apply Allow-All Policy to All Namespaces (Manual)
```bash
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
  [[ "$ns" =~ ^kube- ]] && continue
  kubectl apply -f - << EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: cis-default-allow
  namespace: $ns
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector: {}
    - podSelector: {}
  egress:
  - to:
    - namespaceSelector: {}
    - podSelector: {}
EOF
done
```

---

## Command Reference

| Task | Command |
|------|---------|
| **Audit** | `bash Level_1_Master_Node/5.3.2_audit.sh` |
| **Remediate** | `python3 network_policy_manager.py --remediate` |
| **Dry-Run** | `python3 network_policy_manager.py --remediate --dry-run` |
| **Include System** | `python3 network_policy_manager.py --remediate --include-system` |
| **Verbose** | `python3 network_policy_manager.py --remediate --verbose` |
| **JSON Output** | `python3 network_policy_manager.py --remediate --json` |
| **List Policies** | `kubectl get networkpolicy --all-namespaces` |
| **View Policy** | `kubectl get networkpolicy -n <ns> -o yaml` |
| **Delete Policy** | `kubectl delete networkpolicy cis-default-allow -n <ns>` |

---

## Exit Codes

| Code | Meaning | Action |
|------|---------|--------|
| 0 | ✅ PASS | All namespaces compliant |
| 1 | ✅ FIXED | Remediation applied |
| 2 | ❌ ERROR | Failure - check kubectl access |

---

## Common Issues & Fixes

### kubectl: command not found
```bash
# Install kubectl
# Ubuntu/Debian
sudo apt-get install -y kubectl

# MacOS
brew install kubectl

# Verify
kubectl version --client
```

### Error: insufficient privileges
```bash
# Verify permissions
kubectl auth can-i create networkpolicies --all-namespaces

# If not, ask cluster admin for RBAC role:
kubectl create clusterrolebinding admin-binding \
  --clusterrole=cluster-admin \
  --user=your-username
```

### Policy applied but traffic broken
```bash
# Check if policy is actually applied
kubectl get networkpolicy -n production

# Test connectivity between pods
kubectl exec -it <pod1> -n production -- \
  ping <pod2>.<pod2_ns>.svc.cluster.local

# Check pod labels (needed by policy selectors)
kubectl get pods -n production --show-labels
```

---

## Safety Checklist

- [ ] Test in dev/staging first
- [ ] Have kubectl admin access
- [ ] Backup current policies: `kubectl get networkpolicy -A -o yaml > backup.yaml`
- [ ] Run with `--dry-run` first
- [ ] Verify audit passes after remediation
- [ ] Monitor traffic for issues (at least 1 hour)
- [ ] Have rollback plan (see Cleanup section)

---

## Cleanup (Remove Policies)

### Remove from Single Namespace
```bash
kubectl delete networkpolicy cis-default-allow -n production
```

### Remove from All Namespaces
```bash
kubectl delete networkpolicy cis-default-allow --all-namespaces
```

### Remove with Selector
```bash
kubectl delete networkpolicy \
  -l cis-benchmark=5.3.2 \
  --all-namespaces
```

---

## Environment Variables (for cis_k8s_unified.py)

```bash
# Skip system namespaces (default: true)
export SKIP_SYSTEM_NS=true

# Dry run mode (default: false)
export DRY_RUN=false

# Enable verbose output (default: false)
export VERBOSE=true
```

---

## Integration with cis_k8s_unified.py

```bash
# Run just this check
python3 cis_k8s_unified.py --check 5.3.2

# Remediate this check
python3 cis_k8s_unified.py --remediate --check 5.3.2

# Interactive mode
python3 cis_k8s_unified.py  # Then select 5.3.2
```

---

## Policy Structure (What Gets Applied)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: cis-default-allow
  namespace: {namespace}
  labels:
    cis-benchmark: "5.3.2"
    app: network-policy-manager
spec:
  podSelector: {}                    # ← All pods
  policyTypes:
  - Ingress                          # ← Allow inbound
  - Egress                           # ← Allow outbound
  ingress:
  - from:
    - namespaceSelector: {}          # ← From any namespace
    - podSelector: {}                # ← From any pod
  egress:
  - to:
    - namespaceSelector: {}          # ← To any namespace
    - podSelector: {}                # ← To any pod
```

**Effect**: All traffic allowed (audit requirement met, no disruption)

---

## Monitoring After Deployment

### Check Policy Status
```bash
# Show all policies with their rules
kubectl get networkpolicy -A -o wide

# Show policies labeled as CIS 5.3.2
kubectl get networkpolicy -A -l cis-benchmark=5.3.2

# Count policies by namespace
kubectl get networkpolicy -A --no-headers | cut -d' ' -f1 | sort | uniq -c
```

### Verify Audit Passes
```bash
# Should show all namespaces compliant
bash Level_1_Master_Node/5.3.2_audit.sh
# Expected: [+] PASS: All N checked namespaces have at least one NetworkPolicy defined
```

### Monitor Pod Connectivity
```bash
# Create test pods
kubectl run client --image=busybox -n default -- sleep 3600
kubectl run server --image=busybox -n default -- sleep 3600

# Test connectivity
kubectl exec -it client -n default -- wget -O- http://server.default.svc.cluster.local
# Should succeed (policy allows it)

# Cleanup
kubectl delete pod client server -n default
```

---

## Next Steps

1. **Today**: Run audit, review results
2. **Day 1**: Run remediation in dev/staging
3. **Day 2-3**: Monitor for issues
4. **Day 4**: Run in production if tests pass
5. **Week 2**: Replace allow-all with restrictive policies per namespace

---

## Quick Syntax Reference

### Check Namespace Compliance
```bash
# Does namespace have any policy?
kubectl get networkpolicy -n <ns> --no-headers | wc -l
# Output: 0 = non-compliant, 1+ = compliant
```

### Create Custom Policy
```bash
kubectl apply -f - << 'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: my-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: production
      podSelector:
        matchLabels:
          role: frontend
EOF
```

---

## Performance Tips

- Apply policies during low-traffic windows
- Use `--dry-run` first for large clusters (500+ namespaces)
- Monitor API server load during batch operations
- Consider gradually applying rather than all at once

---

## Version Info

| Component | Version | Location |
|-----------|---------|----------|
| Script | 1.0 | `network_policy_manager.py` |
| Guide | 1.0 | `docs/CIS_5.3.2_NETWORKPOLICY_GUIDE.md` |
| Python | 3.6+ | Stdlib only |
| Kubernetes | 1.19+ | kubectl integration |

---

## Support Resources

- 📖 Full Guide: `docs/CIS_5.3.2_NETWORKPOLICY_GUIDE.md`
- 🔧 Bash Scripts: `Level_1_Master_Node/5.3.2_*.sh`
- 🐍 Python Implementation: `network_policy_manager.py`
- 📋 Audit Results: JSON output with `--json` flag

---

**Last Updated**: December 9, 2025 | **Status**: ✅ Production Ready
