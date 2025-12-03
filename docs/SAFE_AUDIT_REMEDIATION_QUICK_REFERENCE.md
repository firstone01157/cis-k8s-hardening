# Safe Audit Logging Remediation - Quick Reference

## Quick Start (60 seconds)

```bash
# 1. SSH to your Kubernetes master node
ssh user@master-node

# 2. Run the remediation script
sudo bash /path/to/safe_audit_remediation.sh

# 3. Wait for completion (2-3 minutes)
# 4. Verify: kubectl get nodes (should show all ready)
```

## What Gets Created

| Item | Location | Purpose |
|------|----------|---------|
| Audit Log Dir | `/var/log/kubernetes/audit/` | Stores audit logs |
| Audit Policy | `/var/log/kubernetes/audit/audit-policy.yaml` | Defines what to log |
| Audit Logs | `/var/log/kubernetes/audit/audit.log*` | Generated audit records |
| Manifest Backup | `/var/backups/kubernetes/kube-apiserver.yaml.backup_*` | Safe rollback |

## Flags Added to kube-apiserver

```
--audit-log-path=/var/log/kubernetes/audit/audit.log
--audit-policy-file=/var/log/kubernetes/audit/audit-policy.yaml
--audit-log-maxage=30           # Delete logs older than 30 days
--audit-log-maxbackup=10        # Keep max 10 backup files
--audit-log-maxsize=100         # Rotate at 100 MB
```

## Critical Additions to Manifest

### volumeMounts (Container)
```yaml
volumeMounts:
  - name: audit-log
    mountPath: /var/log/kubernetes/audit
    readOnly: false
  - name: audit-policy
    mountPath: /var/log/kubernetes/audit/audit-policy.yaml
    readOnly: true
    subPath: audit-policy.yaml
```

### volumes (Pod)
```yaml
volumes:
  - name: audit-log
    hostPath:
      path: /var/log/kubernetes/audit
      type: DirectoryOrCreate
  - name: audit-policy
    hostPath:
      path: /var/log/kubernetes/audit/audit-policy.yaml
      type: FileOrCreate
```

## Verification Commands

```bash
# Check if flags are set
ps aux | grep kube-apiserver | grep audit

# Verify manifest structure
grep -A5 volumeMounts /etc/kubernetes/manifests/kube-apiserver.yaml
grep -A5 "volumes:" /etc/kubernetes/manifests/kube-apiserver.yaml

# Check pod status
kubectl get pod -n kube-system -l component=kube-apiserver

# Run CIS audit checks
bash Level_1_Master_Node/1.2.16_audit.sh
bash Level_1_Master_Node/1.2.17_audit.sh
bash Level_1_Master_Node/1.2.18_audit.sh
bash Level_1_Master_Node/1.2.19_audit.sh

# View audit logs
tail -f /var/log/kubernetes/audit/audit.log | jq .
```

## If Something Goes Wrong

```bash
# 1. Identify the backup
ls -la /var/backups/kubernetes/kube-apiserver.yaml.backup_*

# 2. Restore the backup
sudo cp /var/backups/kubernetes/kube-apiserver.yaml.backup_TIMESTAMP \
        /etc/kubernetes/manifests/kube-apiserver.yaml

# 3. Wait for kube-apiserver to restart
sleep 30

# 4. Verify recovery
kubectl get nodes
```

## Common Issues & Fixes

| Issue | Fix |
|-------|-----|
| "Must run as root" | Use `sudo bash script.sh` |
| "Manifest not found" | Verify you're on master node: `ls /etc/kubernetes/manifests/` |
| "Pod in CrashLoopBackOff" | Rollback using backup (see above) |
| "Flags not in kube-apiserver" | Wait 60 seconds and retry: `ps aux \| grep kube-apiserver` |
| "Audit logs not being written" | Check directory permissions: `ls -ld /var/log/kubernetes/audit/` |

## Files Included

| File | Purpose |
|------|---------|
| `safe_audit_remediation.sh` | Main remediation script (RECOMMENDED) |
| `safe_audit_remediation.py` | Alternative Python version |
| `verify_audit_remediation.sh` | Verification script |
| `SAFE_AUDIT_REMEDIATION_GUIDE.md` | Full documentation |
| `SAFE_AUDIT_REMEDIATION_QUICK_REFERENCE.md` | This file |

## CIS Checks Fixed

- ✓ **CIS 1.2.16** - `--audit-log-path` argument is set
- ✓ **CIS 1.2.17** - `--audit-log-maxage` is set to 30
- ✓ **CIS 1.2.18** - `--audit-log-maxbackup` is set to 10  
- ✓ **CIS 1.2.19** - `--audit-log-maxsize` is set to 100

## Key Points

🔑 **Why Previous Attempts Failed:**
- Directory didn't exist → Pod couldn't write logs
- Audit policy file missing → Pod failed to start
- No volumeMounts → Container couldn't access directory
- No volumes → Pod couldn't mount host directory
- YAML indentation errors → Manifest syntax invalid

✅ **What This Script Does:**
- Creates all required directories and files
- Adds all required flags
- Adds volumeMounts to container spec
- Adds volumes to pod spec
- Validates YAML syntax
- Creates backups before changes
- Restarts kube-apiserver safely

⚠️ **Important:**
- Always create backups before running
- Run on master node only
- Use `sudo` for execution
- Wait 30-60 seconds after restart before checking

## Support

For issues:
1. Check `/var/backups/kubernetes/` for backups
2. Review remediation logs if saved
3. Check kube-apiserver pod logs: `kubectl logs -n kube-system -l component=kube-apiserver`
4. Rollback if needed (see "If Something Goes Wrong" above)

---

**Last Updated:** 2025-11-26  
**Version:** 1.0
