# CIS Kubernetes Hardening - Quick Reference Card

**Last Updated**: December 9, 2025 | **Status**: ✅ Production Ready

---

## 🚀 Quick Start (5 minutes)

```bash
# 1. Run complete audit
python3 cis_k8s_unified.py --audit

# 2. Check output for:
#    - Automation Health: % of scripts working (target >85%)
#    - Audit Readiness: % CIS compliant (target >70%)
#    - Action Items: What needs fixing

# 3. If needed, apply hardening
python3 cis_1x_hardener.py --dry-run          # Preview
python3 cis_1x_hardener.py --harden-all       # Apply
python3 network_policy_manager.py --create-default-deny
```

---

## 📊 Scoring System

### Two Metrics (Not One!)

| Metric | Formula | What It Means | Target |
|--------|---------|---------------|--------|
| **Automation Health** | Pass / (Pass+Fail) | Script effectiveness | >85% |
| **Audit Readiness** | Pass / Total | True CIS compliance | >70% |

### Color Coding

| Range | Color | Status |
|-------|-------|--------|
| 90-100% | 🟢 | Excellent |
| 80-89% | 🟢 | Good |
| 70-79% | 🟡 | Acceptable |
| 50-69% | 🟡 | Needs Improvement |
| <50% | 🔴 | Critical |

---

## 🛠️ Main Tools

### 1. Unified Runner (Orchestration)
```bash
python3 cis_k8s_unified.py [OPTIONS]

--audit                    # Run all CIS checks
--audit --master           # Master nodes only
--audit --worker           # Worker nodes only
--remediate                # Apply fixes
--remediate --dry-run      # Preview
--json-output              # Machine-readable output
```

### 2. Control Plane Hardener (CIS 1.x)
```bash
python3 cis_1x_hardener.py [OPTIONS]

--harden-all               # Apply all 32 controls
--component apiserver      # API Server only (23 controls)
--component controller     # Controller Manager only (7)
--component scheduler      # Scheduler only (2)
--requirement 1.2.1        # Single control
--dry-run                  # Preview changes
--json-output              # Machine-readable
```

### 3. NetworkPolicy Manager (CIS 5.3.2)
```bash
python3 network_policy_manager.py [OPTIONS]

--check                    # Audit namespaces
--create-default-deny      # Deploy policies
--remove-policies          # Clean up
--verify                   # Validate deployment
--namespace NAME           # Specific namespace
```

---

## 📋 CIS Control Overview

### CIS 1.x Control Plane (32 Controls)

| Component | Controls | Key Settings |
|-----------|----------|--------------|
| **API Server** | 23 (1.2.1-1.2.26) | auth, TLS, RBAC, audit, encryption |
| **Controller Manager** | 7 (1.3.1-1.3.7) | service accounts, certs, localhost |
| **Scheduler** | 2 (1.4.1-1.4.2) | profiling, localhost |

### CIS 5.2.x Pod Security
- **Status**: ✅ Already verified & configured
- **Action**: No changes needed

### CIS 5.3.2 NetworkPolicy
- **Level 1 Requirement**: All namespaces have NetworkPolicy
- **Implementation**: Automated default-deny policies

---

## ⚙️ Key Flags & Options

### Common Flags

```bash
--dry-run          # Preview changes, don't apply
--verbose          # Show detailed output
--json-output      # JSON format for scripts
--quiet            # Minimal output
--force            # Override safety checks
--backup           # Create backups (automatic)
```

### Filtering

```bash
--master           # Master nodes only
--worker           # Worker nodes only  
--level 1          # CIS Level 1 only
--component NAME   # Specific component
--requirement ID   # Single requirement (e.g., 1.2.1)
```

### Output

```bash
--json-output      # JSON format
--csv-output       # CSV report
--html-output      # HTML report
--save FILE        # Save to file
```

---

## 📁 Directory Structure

```
cis-k8s-hardening/
├── cis_k8s_unified.py              # Main runner
├── cis_1x_hardener.py              # Control plane hardener
├── network_policy_manager.py       # NetworkPolicy automation
├── Level_1_Master_Node/            # CIS 1.x audit/remediate
├── Level_1_Worker_Node/
├── docs/
│   ├── DUAL_METRIC_SCORING_GUIDE.md
│   ├── CIS_1X_HARDENER_GUIDE.md
│   ├── NETWORKPOLICY_IMPLEMENTATION_GUIDE.md
│   └── [9 more guides]
├── logs/                           # Execution logs
├── results/                        # Test results
└── backups/                        # Manifest backups
```

---

## 🔍 Diagnostics

### Check Specific Issues

```bash
# API Server flags
kubectl describe pod kube-apiserver -n kube-system | grep -A5 "Command:"

# Controller Manager
kubectl describe pod kube-controller-manager -n kube-system | grep -A5 "Command:"

# NetworkPolicies
kubectl get networkpolicy -A

# Pod Security Standards
kubectl get pods -A --pod-spec='...' | grep securityStandard
```

### View Logs

```bash
# Execution logs
tail -f logs/cis_k8s_unified.log

# Specific component
grep "apiserver\|controller\|scheduler" logs/*.log

# Recent changes
tail -100 logs/harden_manifests.log
```

---

## ✅ Pre-Hardening Checklist

- [ ] Kubernetes 1.19+ (verify: `kubectl version`)
- [ ] Cluster admin access (verify: `kubectl auth can-i create clusterroles`)
- [ ] Control plane accessible (verify: `kubectl cluster-info`)
- [ ] Manifests readable (verify: `ls -la /etc/kubernetes/manifests/`)
- [ ] Recent backup exists (verify: `ls -la backups/`)
- [ ] No other CIS tools running
- [ ] Maintenance window scheduled

---

## ✅ Post-Hardening Checklist

**After running hardening:**

- [ ] Check Automation Health ✓ >85%
- [ ] Check Audit Readiness ✓ >70%
- [ ] Verify API server is running (should restart)
- [ ] Verify Control Manager is running
- [ ] Verify Scheduler is running
- [ ] Check application connectivity
- [ ] Verify audit logging
- [ ] Confirm NetworkPolicies deployed
- [ ] Run full audit again

```bash
# Quick verification
python3 cis_k8s_unified.py --audit | grep -E "AUTOMATION|AUDIT|Excellent|Good"
```

---

## 🔧 Troubleshooting

### API Server Won't Start

```bash
# Check logs
kubectl logs -n kube-system kube-apiserver-<node>

# Verify YAML syntax
python3 -m yaml /etc/kubernetes/manifests/kube-apiserver.yaml

# Rollback
cp backups/kube-apiserver.yaml.bak /etc/kubernetes/manifests/kube-apiserver.yaml

# Wait for restart
sleep 30
kubectl get pods -n kube-system | grep kube-apiserver
```

### Scripts Show "Permission Denied"

```bash
# Make executable
chmod +x *.sh *.py

# Verify
ls -la cis_k8s_unified.py | head -1
# Should show: -rwxr-xr-x
```

### Low Scores Despite Remediation

```bash
# Check what's failing
python3 cis_1x_hardener.py --json-output | grep "fail\|error"

# Check manifest syntax
kubectl apply -f /etc/kubernetes/manifests/ --dry-run=client

# View differences
diff backups/kube-apiserver.yaml.bak /etc/kubernetes/manifests/kube-apiserver.yaml
```

---

## 📈 Workflow Examples

### Weekly Assessment

```bash
#!/bin/bash
# Weekly compliance check

echo "=== Weekly CIS Hardening Assessment ==="

# Run audit
python3 cis_k8s_unified.py --audit --json-output > assessment.json

# Extract metrics
AUTO=$(jq '.automation_health' assessment.json)
AUDIT=$(jq '.audit_readiness' assessment.json)

echo "Automation Health: $AUTO%"
echo "Audit Readiness:   $AUDIT%"

# Alert if declining
if (( $(echo "$AUTO < 80" | bc -l) )); then
    echo "⚠ WARNING: Automation health declining"
    # Send alert
fi

# Archive results
mkdir -p results/$(date +%Y-%m-%d)
mv assessment.json results/$(date +%Y-%m-%d)/
```

### Remediation Sprint

```bash
#!/bin/bash
# Apply hardening incrementally

COMPONENTS=("apiserver" "controller" "scheduler")

for comp in "${COMPONENTS[@]}"; do
    echo "Hardening $comp..."
    python3 cis_1x_hardener.py \
        --component "$comp" \
        --dry-run > dryrun.txt
    
    if grep -q "ERROR\|FAIL" dryrun.txt; then
        echo "⚠ Issues found in dry-run. Skipping."
        continue
    fi
    
    python3 cis_1x_hardener.py --component "$comp"
    sleep 60  # Wait for restart
    
    # Verify
    if python3 cis_k8s_unified.py --audit | grep -q "Excellent\|Good"; then
        echo "✓ $comp hardened successfully"
    else
        echo "✗ $comp hardening issues detected"
    fi
done
```

---

## 📞 When Things Break

### Emergency Rollback

```bash
# Stop kubelet to prevent enforcement
systemctl stop kubelet

# Restore all manifests
for file in backups/*.yaml.bak; do
    cp "$file" "/etc/kubernetes/manifests/$(basename ${file%.bak})"
done

# Restart kubelet
systemctl start kubelet

# Verify recovery
sleep 30
kubectl get pods -n kube-system
```

### Get Help

1. **Check logs**: `tail -100 logs/cis_k8s_unified.log`
2. **Review docs**: See `docs/DOCUMENTATION_INDEX.md`
3. **Run diagnostics**: `python3 cis_k8s_unified.py --audit --verbose`
4. **Check diffs**: `diff backups/*.bak /etc/kubernetes/manifests/`

---

## 🎯 Performance Targets

| Operation | Expected Time |
|-----------|----------------|
| Audit (quick scan) | 30-45s |
| Audit (full check) | 60-90s |
| Remediate (single control) | 5-10s |
| Remediate (all 32 controls) | 2-5 min |
| Score calculation | <100ms |

---

## 📊 Compliance Status Reference

### Automation Health Meaning

| Score | Status | Action |
|-------|--------|--------|
| 95-100% | Perfect | Maintain, no action needed |
| 85-94% | Good | Minor script fixes if needed |
| 70-84% | Fair | Review failing scripts |
| 50-69% | Poor | Fix multiple script issues |
| <50% | Broken | Complete remediation needed |

### Audit Readiness Meaning

| Score | Status | Action |
|-------|--------|--------|
| 85-100% | Ready | Audit-prepared, full compliance |
| 70-84% | Nearly Ready | Minor policy work needed |
| 50-69% | In Progress | Significant policy implementation needed |
| 30-49% | Early Stage | Long way to audit-ready |
| <30% | Critical | Extensive hardening required |

---

## 🔐 Safety Principles

✅ **Always preview** with `--dry-run`  
✅ **Always backup** (automatic, but verify)  
✅ **Start with master** (test fully before workers)  
✅ **Apply incrementally** (one component at a time)  
✅ **Verify after each change** (run audit between)  
✅ **Monitor for issues** (watch logs and metrics)  
✅ **Maintain rollback** (keep recent backups)  

---

## 📚 Documentation Map

| Need | Document |
|------|-----------|
| How scoring works? | DUAL_METRIC_SCORING_GUIDE.md |
| How to use hardener? | CIS_1X_HARDENER_GUIDE.md |
| What are 32 controls? | CIS_1X_REQUIREMENTS_SPEC.md |
| How to deploy NetworkPolicy? | NETWORKPOLICY_IMPLEMENTATION_GUIDE.md |
| How to test changes? | SCORING_SYSTEM_TEST_GUIDE.md |
| Complete overview? | IMPLEMENTATION_SUMMARY.md |
| How to get started? | README.md |
| All docs listed? | DOCUMENTATION_INDEX.md |

---

## 🎓 Key Concepts

**Automation Health** = Pass / (Pass + Fail)
- Measures: How well are remediation scripts working?
- Ignores: Manual checks (not script-automated)
- Improves: By fixing failing scripts

**Audit Readiness** = Pass / Total
- Measures: What's our true CIS compliance?
- Includes: All checks (manual = non-passing)
- Improves: By implementing all controls (script + manual)

**Safety Mode** = Preview first, apply after confirmation
- All scripts support `--dry-run`
- Backups automatic for all manifest changes
- Kubelet can restart components if issues occur

---

**This is your quick reference. For details, see full documentation.**

**Remember**: ✅ Preview → ✅ Backup → ✅ Execute → ✅ Verify

---

**Version**: 1.0 | **Updated**: December 9, 2025 | **Status**: ✅ Current
