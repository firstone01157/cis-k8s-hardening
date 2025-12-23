# CIS Kubernetes Benchmark 1.x Hardening - Python Wrapper Guide

## Overview

The `cis_1x_hardener.py` script automates hardening of Kubernetes control plane components (API Server, Controller Manager, Scheduler) for CIS Benchmark Level 1 requirements.

**Key Features**:
- ✅ Batch processing of multiple CIS requirements
- ✅ Python wrapper around `harden_manifests.py` CLI
- ✅ Automatic manifest path resolution
- ✅ Dry-run mode for preview without changes
- ✅ JSON output for reporting
- ✅ Zero external dependencies (stdlib only)
- ✅ Comprehensive error handling

---

## Quick Start

### 1. Harden All Components
```bash
python3 cis_1x_hardener.py --all
```

**Output**:
```
[✓] 1.2.1: PASS
[✓] 1.2.2: PASS
...
============================================================
Summary: 35/35 checks passed
Success Rate: 100.0%
============================================================
```

### 2. Harden Specific Component
```bash
# API Server only
python3 cis_1x_hardener.py --manifest-type apiserver

# Controller Manager only
python3 cis_1x_hardener.py --manifest-type controller-manager

# Scheduler only
python3 cis_1x_hardener.py --manifest-type scheduler
```

### 3. Dry-Run (Preview Without Changes)
```bash
python3 cis_1x_hardener.py --all --dry-run
```

### 4. Verbose Output
```bash
python3 cis_1x_hardener.py --all --verbose
```

### 5. JSON Report
```bash
python3 cis_1x_hardener.py --all --json | jq .
```

---

## CIS 1.x Requirements Reference

### CIS 1.2.x - API Server Hardening (23 checks)

| Check ID | Flag | Value | Description |
|----------|------|-------|-------------|
| **1.2.1** | `--anonymous-auth` | `false` | Disable anonymous authentication |
| **1.2.2** | `--basic-auth-file` | (remove) | Disable basic auth |
| **1.2.3** | `--token-auth-file` | (remove) | Disable token auth file |
| **1.2.4** | `--kubelet-https` | `true` | Enable kubelet HTTPS |
| **1.2.5** | `--kubelet-client-certificate` | `/etc/kubernetes/pki/apiserver-kubelet-client.crt` | Set kubelet client cert |
| **1.2.6** | `--kubelet-certificate-authority` | `/etc/kubernetes/pki/ca.crt` | Set kubelet CA cert |
| **1.2.7** | `--authorization-mode` | `Node,RBAC` | Enable Node,RBAC authorization |
| **1.2.8** | `--client-ca-file` | `/etc/kubernetes/pki/ca.crt` | Set client CA file |
| **1.2.10** | `--enable-admission-plugins` | `NodeRestriction` | Enable NodeRestriction plugin |
| **1.2.11** | `--insecure-port` | `0` | Disable insecure port |
| **1.2.12** | `--insecure-bind-address` | (remove) | Disable insecure bind address |
| **1.2.13** | `--secure-port` | `6443` | Set secure port |
| **1.2.14** | `--tls-cert-file` | `/etc/kubernetes/pki/apiserver.crt` | Set TLS cert file |
| **1.2.15** | `--tls-private-key-file` | `/etc/kubernetes/pki/apiserver.key` | Set TLS key file |
| **1.2.16** | `--tls-cipher-suites` | (strong ciphers) | Enable strong ciphers |
| **1.2.17** | `--audit-log-path` | `/var/log/kubernetes/audit/audit.log` | Enable audit logging |
| **1.2.18** | `--audit-log-maxage` | `30` | Set audit log max age |
| **1.2.19** | `--audit-log-maxbackup` | `10` | Set audit log max backups |
| **1.2.20** | `--audit-log-maxsize` | `100` | Set audit log max size |
| **1.2.21** | `--request-timeout` | `60s` | Set request timeout |
| **1.2.22** | `--service-account-lookup` | `true` | Enable service account lookup |
| **1.2.25** | `--encryption-provider-config` | `/etc/kubernetes/enc/encryption-provider-config.yaml` | Enable encryption at rest |
| **1.2.26** | `--api-audiences` | `kubernetes.default.svc` | Set API audiences |

### CIS 1.3.x - Controller Manager Hardening (7 checks)

| Check ID | Flag | Value | Description |
|----------|------|-------|-------------|
| **1.3.1** | `--terminated-pod-gc-threshold` | `10` | Set pod GC threshold |
| **1.3.2** | `--profiling` | `false` | Disable profiling |
| **1.3.3** | `--use-service-account-credentials` | `true` | Use individual SA credentials |
| **1.3.4** | `--service-account-private-key-file` | `/etc/kubernetes/pki/sa.key` | Set SA private key file |
| **1.3.5** | `--root-ca-file` | `/etc/kubernetes/pki/ca.crt` | Set root CA file |
| **1.3.6** | `--feature-gates` | `RotateKubeletServerCertificate=true` | Enable kubelet cert rotation |
| **1.3.7** | `--bind-address` | `127.0.0.1` | Bind to localhost |

### CIS 1.4.x - Scheduler Hardening (2 checks)

| Check ID | Flag | Value | Description |
|----------|------|-------|-------------|
| **1.4.1** | `--profiling` | `false` | Disable profiling |
| **1.4.2** | `--bind-address` | `127.0.0.1` | Bind to localhost |

---

## Usage Examples

### Example 1: Harden Just the API Server
```bash
python3 cis_1x_hardener.py --manifest-type apiserver
```

This applies all CIS 1.2.x requirements to `/etc/kubernetes/manifests/kube-apiserver.yaml`.

### Example 2: Dry-Run to Preview All Changes
```bash
python3 cis_1x_hardener.py --all --dry-run
```

Shows what would be changed without modifying manifests.

### Example 3: Verbose Hardening with Full Output
```bash
python3 cis_1x_hardener.py --all --verbose
```

Displays executed commands and detailed progress.

### Example 4: Generate JSON Report
```bash
python3 cis_1x_hardener.py --all --json > cis_hardening_report.json
```

Useful for CI/CD pipelines and automated reporting.

### Example 5: Harden Only Controller Manager
```bash
python3 cis_1x_hardener.py --manifest-type controller-manager --verbose
```

Applies CIS 1.3.x requirements only.

---

## Integration with Bash Scripts

The Python wrapper integrates with your existing bash remediation scripts.

### Example Bash Script Integration
```bash
#!/bin/bash
# Wrapper for CIS 1.2.1 remediation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
HARDENER_SCRIPT="$PROJECT_ROOT/cis_1x_hardener.py"

if [ ! -f "$HARDENER_SCRIPT" ]; then
    echo "[ERROR] cis_1x_hardener.py not found"
    exit 1
fi

# Run hardening for API Server
python3 "$HARDENER_SCRIPT" --manifest-type apiserver --verbose

if [ $? -eq 0 ]; then
    echo "[FIXED] CIS 1.2.x hardening completed"
    exit 0
else
    echo "[ERROR] Hardening failed"
    exit 1
fi
```

---

## Environment Variables

The script respects these environment variables:

| Variable | Default | Purpose |
|----------|---------|---------|
| `DRY_RUN` | `false` | Set to `true` for preview mode |
| `VERBOSE` | `false` | Set to `true` for detailed output |
| `HARDEN_SCRIPT` | (auto-detect) | Path to `harden_manifests.py` |

**Example**:
```bash
DRY_RUN=true VERBOSE=true python3 cis_1x_hardener.py --all
```

---

## Exit Codes

| Code | Meaning | Action |
|------|---------|--------|
| **0** | ✅ Success | All checks applied successfully |
| **1** | ⚠️ Partial | Some checks may have issues |
| **2** | ❌ Error | Failure occurred (e.g., manifest not found) |

---

## How It Works

### Internal Flow

1. **Initialize**: Load `harden_manifests.py` (auto-detect location)
2. **Select Mode**: Determine which components to harden (apiserver, controller-manager, scheduler)
3. **Resolve Paths**: Locate manifest files with fallback searches
4. **Apply Requirements**: Iterate through CIS requirements and call `harden_manifests.py`
5. **Touch Manifests**: Force kubelet reload by updating file timestamps
6. **Report Results**: Display summary with statistics

### Manifest Modification Process

```
┌─────────────────────────────────────────┐
│ cis_1x_hardener.py (batch orchestrator) │
└──────────────────┬──────────────────────┘
                   │
                   └──> For each CIS requirement:
                        1. Build command with flag + value
                        2. Call harden_manifests.py via subprocess
                        3. Handle response (PASS/ERROR)
                        4. Update manifest timestamp
                        5. Record result
```

### Manifest Path Resolution

```
Primary Path: /etc/kubernetes/manifests/kube-apiserver.yaml
     ↓
If not found, try:
     ├─ /etc/kubernetes/manifests/apiserver.yaml
     ├─ /home/master/manifests/kube-apiserver.yaml
     ├─ Current directory + relative path
     └─ Auto-search parent directories
```

---

## Common Operations

### Check Current API Server Configuration
```bash
# List current flags
grep "^    - --" /etc/kubernetes/manifests/kube-apiserver.yaml

# Check specific flag
grep "anonymous-auth" /etc/kubernetes/manifests/kube-apiserver.yaml
```

### Verify Hardening was Applied
```bash
# Check if changes took effect
kubectl describe pod -n kube-system kube-apiserver-<node-name> | grep -i "Arguments" -A 20
```

### Rollback Changes (Using Backups)
```bash
# List backups
ls /etc/kubernetes/manifests/backups/

# Restore from backup
cp /etc/kubernetes/manifests/backups/kube-apiserver_20251209_173000.yaml \
   /etc/kubernetes/manifests/kube-apiserver.yaml
```

### Manual Flag Update
```bash
# For cases where the wrapper isn't suitable
python3 harden_manifests.py \
    --manifest=/etc/kubernetes/manifests/kube-apiserver.yaml \
    --flag=--anonymous-auth \
    --value=false \
    --ensure=present
```

---

## Troubleshooting

### Error: "Manifest not found"
```bash
# Check manifest location
ls -la /etc/kubernetes/manifests/

# Verify file permissions
stat /etc/kubernetes/manifests/kube-apiserver.yaml

# Try with explicit path
python3 cis_1x_hardener.py \
    --harden-script /path/to/harden_manifests.py \
    --all
```

### Error: "harden_manifests.py not found"
```bash
# Locate the script
find / -name "harden_manifests.py" 2>/dev/null

# Provide explicit path
python3 cis_1x_hardener.py \
    --harden-script /home/first/cis-k8s-hardening/harden_manifests.py \
    --all
```

### Static Pod Not Reloading
```bash
# Kubelet watches manifest directory for changes
# Touch manifest to force reload
touch /etc/kubernetes/manifests/kube-apiserver.yaml

# Verify pod is restarting
kubectl get pods -n kube-system kube-apiserver-<node> -w

# Check kubelet logs
journalctl -u kubelet -f | grep "apiserver"
```

### API Server Stops Responding
```bash
# If API Server restarts too aggressively:
# 1. Check the applied flags for syntax errors
grep "^    - --" /etc/kubernetes/manifests/kube-apiserver.yaml

# 2. Review kubelet logs
journalctl -u kubelet -n 100

# 3. Restore from backup if needed
cp /etc/kubernetes/manifests/backups/kube-apiserver_*.yaml \
   /etc/kubernetes/manifests/kube-apiserver.yaml
```

---

## Performance Considerations

### Execution Time
- **API Server only**: ~20-30 seconds (23 requirements)
- **Controller Manager only**: ~5-10 seconds (7 requirements)
- **Scheduler only**: ~3-5 seconds (2 requirements)
- **All components**: ~40-50 seconds (32 requirements total)

### Resource Impact
- **Memory**: <50 MB
- **CPU**: Minimal (I/O bound)
- **Downtime**: Typically <30 seconds per component (kubelet-managed restart)

### Best Practices
1. Run during maintenance window
2. Test in dev/staging first
3. Use `--dry-run` before production deployment
4. Monitor cluster after changes

---

## Advanced Usage

### Programmatic Python Usage
```python
from cis_1x_hardener import CIS1xHardener

# Initialize hardener
hardener = CIS1xHardener(dry_run=False, verbose=True)

# Harden specific component
results = hardener.harden_apiserver()

# Get summary
summary = hardener.get_summary()
print(f"Success Rate: {summary['success_rate']}")

# Get JSON report
report = hardener.get_json_report()
```

### Integration with CI/CD
```yaml
# GitLab CI example
harden_k8s:
  stage: harden
  script:
    - python3 cis_1x_hardener.py --all --json > results.json
  artifacts:
    paths:
      - results.json
  only:
    - main
```

### Conditional Hardening
```bash
# Only harden API Server if it's not already hardened
if ! grep -q "anonymous-auth=false" /etc/kubernetes/manifests/kube-apiserver.yaml; then
    python3 cis_1x_hardener.py --manifest-type apiserver
fi
```

---

## References

- **CIS Kubernetes Benchmark**: https://www.cisecurity.org/cis-benchmarks/
- **Kubernetes API Server Docs**: https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/
- **Controller Manager Docs**: https://kubernetes.io/docs/reference/command-line-tools-reference/kube-controller-manager/
- **Scheduler Docs**: https://kubernetes.io/docs/reference/command-line-tools-reference/kube-scheduler/

---

## Support

For issues with the wrapper script:
1. Try with `--verbose` flag
2. Check `harden_manifests.py` directly
3. Review kubelet logs: `journalctl -u kubelet`
4. Ensure manifests are readable/writable

---

**Version**: 1.0  
**Status**: ✅ Production Ready  
**Last Updated**: December 9, 2025
