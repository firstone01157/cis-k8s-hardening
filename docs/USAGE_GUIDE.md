# CIS Kubernetes Benchmark - Config-Driven Remediation Usage Guide

## Quick Start Examples

### Scenario 1: Dry-Run Before Deployment

**Goal:** Preview all remediation changes without applying them.

**Step 1: Update Configuration**
```json
// cis_config.json
{
    "remediation_config": {
        "global": {
            "backup_enabled": true,
            "dry_run": true,  // ← Enable dry-run
            "wait_for_api": true,
            "api_timeout": 30,
            "api_retries": 10
        }
    }
}
```

**Step 2: Run Remediation**
```bash
python3 cis_k8s_unified.py -v

# Select: 2) Remediation only
# Select: 1) Master only
# Select: 1) Level 1
```

**Expected Output:**
```
[INFO] Applying Pod Security Standards (Warn + Audit) to default namespace...
[DRYRUN] Would apply: kubectl label --overwrite namespace default pod-security.kubernetes.io/warn=restricted pod-security.kubernetes.io/audit=restricted
[+] PASS: Applied Warn/Audit policies to default namespace (Safe Mode)
```

**Script Logs:**
```bash
cat /var/log/cis-5.2.1-remediation.log
# [DRYRUN] Would apply: kubectl label ...
# [SUCCESS] CIS 5.2.1 remediation completed
```

✅ **No actual changes made. Ready to apply for real.**

---

### Scenario 2: Skip Problematic Checks

**Goal:** Exclude specific checks from remediation due to custom configuration.

**Step 1: Configure Skip**
```json
// cis_config.json
{
    "remediation_config": {
        "checks": {
            "5.2.1": {
                "enabled": true,
                "skip": true,  // ← Skip this check
                "reason": "Custom pod security policy in place"
            },
            "3.2.1": {
                "enabled": true,
                "skip": false  // ← Apply this check
            }
        }
    }
}
```

**Step 2: Run Remediation**
```bash
python3 cis_k8s_unified.py

# Select: 2) Remediation only
```

**Result:**
```
5.2.1 -> [SKIPPED] Skipped by remediation config
3.2.1 -> [PASS] Successfully applied audit policy
```

**Statistics:**
```
STATISTICS SUMMARY
================================================================================

  MASTER:
    Pass:    1
    Fail:    0
    Manual:  0
    Skipped: 1  ← 5.2.1 skipped as configured
    Total:   2
    Success: 100%
```

---

### Scenario 3: Multi-Namespace Pod Security Configuration

**Goal:** Apply different Pod Security policies to different namespaces.

**Step 1: Configure Per-Namespace Policy**
```json
// cis_config.json
{
    "remediation_config": {
        "checks": {
            "5.2.1": {
                "enabled": true,
                "skip": false,
                "mode": "custom",
                "namespaces": {
                    "default": {
                        "warn": "restricted",
                        "audit": "restricted",
                        "enforce": "disabled"
                    },
                    "kube-system": {
                        "warn": "baseline",
                        "audit": "baseline",
                        "enforce": "disabled"
                    },
                    "production": {
                        "warn": "restricted",
                        "audit": "restricted",
                        "enforce": "restricted"
                    }
                }
            }
        }
    }
}
```

**Step 2: Script Receives Configuration**
```bash
# Python runner passes:
CONFIG_NAMESPACES='{"default": {...}, "kube-system": {...}, "production": {...}}'

# Script parses and applies:
for namespace in default kube-system production; do
    kubectl label --overwrite namespace "${namespace}" ...
done
```

**Step 3: Verify**
```bash
kubectl get ns -L pod-security.kubernetes.io/warn,pod-security.kubernetes.io/audit,pod-security.kubernetes.io/enforce

NAME          WARN         AUDIT        ENFORCE
default       restricted   restricted   <none>
kube-system   baseline     baseline     <none>
production    restricted   restricted   restricted
```

---

### Scenario 4: Custom Audit Levels

**Goal:** Use RequestResponse logging level for maximum visibility.

**Step 1: Configure Audit Level**
```json
// cis_config.json
{
    "remediation_config": {
        "checks": {
            "3.2.1": {
                "enabled": true,
                "skip": false,
                "audit_level": "RequestResponse",  // ← More verbose
                "log_sensitive_resources": true,
                "sensitive_resources": [
                    "secrets",
                    "configmaps",
                    "pods/exec",
                    "pods/attach",
                    "networkpolicies"  // ← Add custom resources
                ]
            }
        }
    }
}
```

**Step 2: Run Remediation**
```bash
python3 cis_k8s_unified.py

# Selects: 2) Remediation only
```

**Step 3: Verify Audit Policy**
```bash
cat /etc/kubernetes/audit-policy.yaml
# Shows: level: RequestResponse for all rules
```

**Step 4: Monitor Audit Logs**
```bash
tail -f /var/log/kubernetes/audit/audit.log | jq 'select(.verb=="exec")'

# Shows all pod exec attempts:
# {
#   "apiVersion": "audit.k8s.io/v1",
#   "level": "RequestResponse",
#   "verb": "create",
#   "user": {"username": "system:kubelet:node-1"},
#   "objectRef": {"resource": "pods", "subresource": "exec", ...},
#   "requestObject": {"command": ["/bin/sh"]},
#   ...
# }
```

---

### Scenario 5: Gradual Rollout with Enforce Mode

**Goal:** First warn/audit, then gradually enforce Pod Security Standards.

**Phase 1: Warn & Audit Only (Safe)**
```json
// Week 1: Enable warnings only
{
    "remediation_config": {
        "checks": {
            "5.2.1": {
                "mode": "warn-audit",
                "environment_overrides": {
                    "WARN_MODE": "restricted",
                    "AUDIT_MODE": "restricted",
                    "ENFORCE_MODE": "disabled"
                }
            }
        }
    }
}
```

**Result:** Pods warned but not blocked
```bash
# Pod creation shows:
# Warning: would violate PodSecurityPolicy: runAsNonRoot, runAsUser
# (But pod is created anyway)
```

**Phase 2: Check Warnings and Fix Issues**
```bash
# Review audit logs
kubectl logs -l component=kubelet | grep "pod-security"

# Identify problematic workloads
kubectl get pods -A -o json | jq '.items[] | select(...has violations...)'

# Fix workloads in staging first
```

**Phase 3: Enable Enforce Mode**
```json
// Week 3: Enable enforcement
{
    "remediation_config": {
        "checks": {
            "5.2.1": {
                "mode": "enforce",
                "environment_overrides": {
                    "ENFORCE_MODE": "restricted"
                }
            }
        }
    }
}
```

**Result:** Non-compliant pods rejected
```bash
# Pod creation fails with:
# Error from server (Forbidden): error when creating "pod.yaml": 
# pods "unsafe-pod" is forbidden: 
# violates PodSecurityPolicy restricted: ...
```

---

### Scenario 6: Emergency Rollback

**Goal:** Quickly disable remediation if issues occur.

**Step 1: Identify Issue**
```bash
# Pods not starting after remediation
kubectl get pods -A | grep CrashLoopBackOff

# Check what changed
grep "Successfully applied" /var/log/cis-*

# Backup was created: /var/backups/cis-remediation/...
```

**Step 2: Disable in Config**
```json
// Temporarily disable problematic checks
{
    "remediation_config": {
        "checks": {
            "5.2.1": {
                "enabled": false  // ← Quick disable
            }
        }
    }
}
```

**Step 3: Restore from Backup**
```bash
# Restore original configuration
cp /var/backups/cis-remediation/kube-apiserver.yaml.bak.* \
   /etc/kubernetes/manifests/kube-apiserver.yaml

# Restart API server
# kubelet will automatically pick up changes

# Wait for health
kubectl get nodes
```

**Step 4: Investigate and Reapply**
```bash
# Fix the issue
# Update configuration
# Test with dry_run: true
# Reapply
```

---

## Environment Variable Reference

### Global Variables (Set by Python Runner)

| Variable | Default | Example | Purpose |
|----------|---------|---------|---------|
| `BACKUP_ENABLED` | true | "true", "false" | Enable backup creation |
| `BACKUP_DIR` | /var/backups/cis-remediation | "/var/backups" | Backup location |
| `DRY_RUN` | false | "true", "false" | Preview without applying |
| `WAIT_FOR_API` | true | "true", "false" | Wait for API server |
| `API_TIMEOUT` | 30 | "60", "120" | kubectl timeout (seconds) |
| `API_RETRIES` | 10 | "5", "20" | API health check retries |

### Pod Security Variables

| Variable | Default | Example | Source |
|----------|---------|---------|--------|
| `PSS_MODE` | warn-audit | warn-only, audit-only, enforce | environment_overrides |
| `WARN_MODE` | restricted | baseline, restricted | Derived from PSS_MODE |
| `AUDIT_MODE` | restricted | baseline, restricted | Derived from PSS_MODE |
| `ENFORCE_MODE` | disabled | disabled, restricted | Derived from PSS_MODE |

### Audit Policy Variables

| Variable | Default | Example | Source |
|----------|---------|---------|--------|
| `AUDIT_LEVEL` | Metadata | Metadata, RequestResponse | environment_overrides |
| `CONFIG_AUDIT_LEVEL` | Metadata | RequestResponse | config.json |
| `CONFIG_LOG_SENSITIVE_RESOURCES` | true | "true", "false" | config.json |

### Check-Specific Variables (Prefixed CONFIG_)

```bash
# For any check configuration key:
CONFIG_MODE=warn-audit
CONFIG_SKIP=false
CONFIG_ENABLED=true
CONFIG_NAMESPACES='{"default": {...}}'
CONFIG_THRESHOLD=12500
```

---

## Debugging Commands

### View Current Configuration
```bash
# Pretty print remediation config
jq '.remediation_config' cis_config.json

# Check specific check
jq '.remediation_config.checks."5.2.1"' cis_config.json
```

### Monitor Remediation Process
```bash
# In terminal 1: Run remediation
python3 cis_k8s_unified.py -vv

# In terminal 2: Watch logs
tail -f /var/log/cis-*.log

# In terminal 3: Watch resources
kubectl get ns,pods -A -w
```

### Test Single Script with Custom Env
```bash
# Run script directly with test variables
export PSS_MODE="enforce"
export DRY_RUN="true"
export CONFIG_CREATE_SECURE_ZONE="true"

bash 5.2.1_remediate.sh

# Check results
cat /var/log/cis-5.2.1-remediation.log
```

### Validate Configuration Syntax
```bash
# Python
python3 -c "
import json
with open('cis_config.json') as f:
    config = json.load(f)
    print(f'Valid JSON, {len(config[\"remediation_config\"][\"checks\"])} checks')
"

# jq
jq '.remediation_config.checks | keys' cis_config.json
```

---

## Common Configuration Patterns

### Pattern 1: Production-Safe (Warn/Audit Only)
```json
{
    "global": {
        "dry_run": false,
        "backup_enabled": true,
        "wait_for_api": true
    },
    "environment_overrides": {
        "PSS_MODE": "warn-audit",
        "AUDIT_LEVEL": "Metadata"
    },
    "checks": {
        "5.2.1": {"mode": "warn-audit"},
        "3.2.1": {"audit_level": "Metadata"}
    }
}
```

### Pattern 2: Development (Enforce Mode)
```json
{
    "environment_overrides": {
        "PSS_MODE": "enforce",
        "AUDIT_LEVEL": "RequestResponse"
    },
    "checks": {
        "5.2.1": {"mode": "enforce"},
        "3.2.1": {"audit_level": "RequestResponse"}
    }
}
```

### Pattern 3: Testing (Dry-Run + Skip Most)
```json
{
    "global": {
        "dry_run": true
    },
    "checks": {
        "5.2.1": {"skip": true},
        "5.6.1": {"skip": true},
        "3.2.1": {"skip": false}  // Only test 3.2.1
    }
}
```

---

## Troubleshooting

### Problem: Script marked SKIPPED but I didn't configure skip
**Solution:** Check both `enabled` and `skip` fields
```bash
jq '.remediation_config.checks."5.2.1" | {enabled, skip}' cis_config.json
```

### Problem: Environment variables not being passed
**Solution:** Check with verbose mode and verify JSON syntax
```bash
python3 cis_k8s_unified.py -vv 2>&1 | grep "env vars"
```

### Problem: Dry-run changes are being applied
**Solution:** Ensure dry_run is false in global config
```bash
jq '.remediation_config.global.dry_run' cis_config.json
# Should print: false
```

### Problem: API server health check timing out
**Solution:** Increase retries and delay
```json
{
    "global": {
        "api_timeout": 60,
        "api_retries": 20
    }
}
```

---

## Summary

The config-driven remediation system provides:

✅ **Flexibility** - Change behavior without editing scripts  
✅ **Safety** - Dry-run before applying  
✅ **Auditability** - All decisions in version control  
✅ **Scalability** - Easy to add new checks  
✅ **Control** - Per-namespace, per-check configuration  

**Start with dry-run, validate changes, then apply with confidence!**
