# CIS 1.x Requirements - Detailed Specification

## Quick Reference Table

### API Server (kube-apiserver.yaml)

| CIS Check | Flag | Value | Rationale | Kubernetes Version |
|-----------|------|-------|-----------|-------------------|
| **1.2.1** | `--anonymous-auth` | `false` | Disable anonymous API access | 1.19+ |
| **1.2.2** | `--basic-auth-file` | (absent) | Disable basic authentication | 1.19+ |
| **1.2.3** | `--token-auth-file` | (absent) | Disable token file authentication | 1.19+ |
| **1.2.4** | `--kubelet-https` | `true` | Enforce HTTPS with kubelet | 1.19+ |
| **1.2.5** | `--kubelet-client-certificate` | (path) | Client cert for kubelet communication | 1.19+ |
| **1.2.6** | `--kubelet-certificate-authority` | (path) | CA cert to verify kubelet | 1.19+ |
| **1.2.7** | `--authorization-mode` | `Node,RBAC` | Enable Node and RBAC authorization | 1.19+ |
| **1.2.8** | `--client-ca-file` | (path) | CA cert for client authentication | 1.19+ |
| **1.2.10** | `--enable-admission-plugins` | (includes) | Enable admission controllers | 1.19+ |
| **1.2.11** | `--insecure-port` | `0` | Disable insecure HTTP port | 1.19+ |
| **1.2.12** | `--insecure-bind-address` | (absent) | Don't bind to insecure address | 1.19+ |
| **1.2.13** | `--secure-port` | `6443` | Use standard secure port | 1.19+ |
| **1.2.14** | `--tls-cert-file` | (path) | HTTPS server certificate | 1.19+ |
| **1.2.15** | `--tls-private-key-file` | (path) | HTTPS server private key | 1.19+ |
| **1.2.16** | `--tls-cipher-suites` | (strong) | Use secure TLS cipher suites | 1.19+ |
| **1.2.17** | `--audit-log-path` | (path) | Enable audit logging | 1.19+ |
| **1.2.18** | `--audit-log-maxage` | `30` | Rotate audit logs after 30 days | 1.19+ |
| **1.2.19** | `--audit-log-maxbackup` | `10` | Keep 10 backups of audit logs | 1.19+ |
| **1.2.20** | `--audit-log-maxsize` | `100` | Rotate logs at 100 MB | 1.19+ |
| **1.2.21** | `--request-timeout` | `60s` | Timeout for API requests | 1.19+ |
| **1.2.22** | `--service-account-lookup` | `true` | Validate service account tokens | 1.19+ |
| **1.2.25** | `--encryption-provider-config` | (path) | Enable encryption at rest | 1.19+ |
| **1.2.26** | `--api-audiences` | (list) | Restrict API server audience | 1.19+ |

### Controller Manager (kube-controller-manager.yaml)

| CIS Check | Flag | Value | Rationale | Kubernetes Version |
|-----------|------|-------|-----------|-------------------|
| **1.3.1** | `--terminated-pod-gc-threshold` | `10` | Garbage collect terminated pods | 1.19+ |
| **1.3.2** | `--profiling` | `false` | Disable pprof profiling | 1.19+ |
| **1.3.3** | `--use-service-account-credentials` | `true` | Use individual service accounts | 1.19+ |
| **1.3.4** | `--service-account-private-key-file` | (path) | Private key for service account signing | 1.19+ |
| **1.3.5** | `--root-ca-file` | (path) | Root CA cert for pod verification | 1.19+ |
| **1.3.6** | `--feature-gates` | `RotateKubeletServerCertificate=true` | Auto-rotate kubelet certificates | 1.19+ |
| **1.3.7** | `--bind-address` | `127.0.0.1` | Bind to localhost | 1.19+ |

### Scheduler (kube-scheduler.yaml)

| CIS Check | Flag | Value | Rationale | Kubernetes Version |
|-----------|------|-------|-----------|-------------------|
| **1.4.1** | `--profiling` | `false` | Disable pprof profiling | 1.19+ |
| **1.4.2** | `--bind-address` | `127.0.0.1` | Bind to localhost | 1.19+ |

---

## API Server Hardening Details

### Authentication & Authorization (1.2.1 - 1.2.8)

**Purpose**: Restrict API access to authorized principals only

```yaml
# Disable anonymous access - always first line of defense
--anonymous-auth=false

# Disable legacy authentication methods
--basic-auth-file=null
--token-auth-file=null

# Require HTTPS with client certificates
--kubelet-https=true
--kubelet-client-certificate=/etc/kubernetes/pki/apiserver-kubelet-client.crt
--kubelet-client-key=/etc/kubernetes/pki/apiserver-kubelet-client.key
--kubelet-certificate-authority=/etc/kubernetes/pki/ca.crt

# Enable RBAC authorization
--authorization-mode=Node,RBAC

# Validate client certificates
--client-ca-file=/etc/kubernetes/pki/ca.crt
```

### Admission Control (1.2.10)

**Purpose**: Enforce security policies at API level

```yaml
# Minimum admission plugins (extend as needed)
--enable-admission-plugins=NodeRestriction,NamespaceLifecycle,ServiceAccount,DefaultStorageClass,PodSecurityPolicy,ResourceQuota
```

**Common Plugins**:
- `NodeRestriction`: Prevents kubelets from modifying other nodes
- `ServiceAccount`: Validates service account tokens
- `PodSecurityPolicy`: Enforces pod security standards
- `ResourceQuota`: Enforces resource limits
- `NetworkPolicy`: Enables network policies

### Network Security (1.2.11 - 1.2.15)

**Purpose**: Secure all API communications

```yaml
# Disable insecure port
--insecure-port=0
--insecure-bind-address=null

# Enable secure HTTPS
--secure-port=6443
--bind-address=0.0.0.0  # Listen on all interfaces (but only on 6443)
--tls-cert-file=/etc/kubernetes/pki/apiserver.crt
--tls-private-key-file=/etc/kubernetes/pki/apiserver.key

# Use strong TLS ciphers (only allow modern, secure suites)
--tls-cipher-suites=TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
```

### Audit Logging (1.2.17 - 1.2.20)

**Purpose**: Track API activity for security monitoring

```yaml
# Enable audit logging
--audit-log-path=/var/log/kubernetes/audit/audit.log

# Manage audit log files
--audit-log-maxage=30          # Retain 30 days
--audit-log-maxbackup=10       # Keep 10 backup files
--audit-log-maxsize=100        # Rotate at 100 MB
--audit-policy-file=/etc/kubernetes/audit-policy.yaml  # Policy configuration
```

### Request Management (1.2.21, 1.2.22)

**Purpose**: Prevent resource exhaustion and ensure service stability

```yaml
# Timeout for API requests
--request-timeout=60s

# Validate service account tokens
--service-account-lookup=true
--service-account-key-file=/etc/kubernetes/pki/sa.pub
```

### Encryption & Tokens (1.2.25, 1.2.26)

**Purpose**: Protect sensitive data at rest

```yaml
# Encryption at rest for etcd
--encryption-provider-config=/etc/kubernetes/enc/encryption-provider-config.yaml

# API audience restriction
--api-audiences=kubernetes.default.svc
```

---

## Controller Manager Hardening Details

### Resource Management (1.3.1)

```yaml
# Garbage collect terminated pods
--terminated-pod-gc-threshold=10  # Default, but explicitly set
```

### Security (1.3.2 - 1.3.5)

```yaml
# Disable profiling endpoint
--profiling=false

# Use individual service accounts per controller
--use-service-account-credentials=true

# Service account key files
--service-account-private-key-file=/etc/kubernetes/pki/sa.key
--service-account-key-file=/etc/kubernetes/pki/sa.pub
--root-ca-file=/etc/kubernetes/pki/ca.crt

# Rotate kubelet certificates automatically
--feature-gates=RotateKubeletServerCertificate=true
--kubelet-certificate-authority=/etc/kubernetes/pki/ca.crt
--kubelet-client-certificate=/etc/kubernetes/pki/controller-manager-kubelet-client.crt
--kubelet-client-key=/etc/kubernetes/pki/controller-manager-kubelet-client.key
```

### Network (1.3.7)

```yaml
# Listen only on localhost (metrics only)
--bind-address=127.0.0.1
```

---

## Scheduler Hardening Details

### Profiling & Network (1.4.1, 1.4.2)

```yaml
# Disable pprof endpoint
--profiling=false

# Listen only on localhost
--bind-address=127.0.0.1
```

---

## Implementation Order

**Recommended sequence** (to minimize cluster disruption):

1. **Phase 1 - Core Security** (High impact, low risk):
   - 1.2.1: `--anonymous-auth=false`
   - 1.2.7: `--authorization-mode=Node,RBAC`
   - 1.3.3: `--use-service-account-credentials=true`
   - 1.4.1: Scheduler `--profiling=false`

2. **Phase 2 - Authentication** (Medium impact, medium risk):
   - 1.2.4-1.2.6: Kubelet HTTPS + certificates
   - 1.2.8: Client CA file
   - 1.2.22: Service account lookup

3. **Phase 3 - Network & TLS** (Medium impact, medium risk):
   - 1.2.11-1.2.15: Port and TLS configuration
   - 1.3.7, 1.4.2: Bind to localhost

4. **Phase 4 - Monitoring & Encryption** (Low impact, important for compliance):
   - 1.2.17-1.2.20: Audit logging
   - 1.2.25: Encryption at rest

5. **Phase 5 - Admission Controllers** (Highest risk):
   - 1.2.10: Enable admission plugins (requires careful planning)

---

## Dependency Notes

### Flags That Often Depend on Configuration Files

These require files to exist before applying:

| Flag | Required File | Impact |
|------|---------------|--------|
| `--audit-log-path` | `/var/log/kubernetes/audit/` | Creates if missing |
| `--audit-policy-file` | `/etc/kubernetes/audit-policy.yaml` | Must exist |
| `--encryption-provider-config` | `/etc/kubernetes/enc/encryption-provider-config.yaml` | Must exist |
| `--kubelet-client-certificate` | `/etc/kubernetes/pki/apiserver-kubelet-client.crt` | Must exist |
| `--tls-cert-file` | `/etc/kubernetes/pki/apiserver.crt` | Must exist |
| `--tls-private-key-file` | `/etc/kubernetes/pki/apiserver.key` | Must exist |

### Pre-flight Checks

```bash
# Verify certificates exist
ls -la /etc/kubernetes/pki/ | grep -E "(apiserver|ca\.crt|sa\.)"

# Verify audit directory
mkdir -p /var/log/kubernetes/audit/
chmod 700 /var/log/kubernetes/audit/

# Verify encryption config
ls -la /etc/kubernetes/enc/encryption-provider-config.yaml
```

---

## Kubernetes Version Compatibility

All requirements are compatible with **Kubernetes 1.19 through 1.34+**.

**Deprecations to watch**:
- `--basic-auth-file`: Deprecated in 1.23, will be removed
- `--token-auth-file`: Deprecated in 1.23, will be removed
- `--insecure-port`: Deprecated in 1.20, will be removed
- Recommended to set all to safe values regardless of current version

---

## Verification Commands

### Verify API Server Hardening

```bash
# Check current flags
grep "^    - --" /etc/kubernetes/manifests/kube-apiserver.yaml | sort

# Verify specific flags are set
for flag in anonymous-auth authorization-mode client-ca-file; do
  grep -q "$flag" /etc/kubernetes/manifests/kube-apiserver.yaml && echo "✓ $flag set" || echo "✗ $flag missing"
done
```

### Verify via kubectl (API Server Pod)

```bash
# View running API Server
kubectl describe pod -n kube-system kube-apiserver-<node-name>

# Extract command with flags
kubectl get pod -n kube-system kube-apiserver-<node-name> -o jsonpath='{.spec.containers[0].command}' | jq .
```

### Verify via kubelet (Manifest)

```bash
# Direct manifest inspection
cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep -A 50 "command:"
```

---

## Rollback Procedure

If hardening causes issues:

```bash
# 1. Stop kubelet from restarting pod
systemctl stop kubelet

# 2. Restore from backup
cp /etc/kubernetes/manifests/backups/kube-apiserver_TIMESTAMP.yaml \
   /etc/kubernetes/manifests/kube-apiserver.yaml

# 3. Restart kubelet
systemctl start kubelet

# 4. Verify cluster is healthy
kubectl get nodes
kubectl get pods -A
```

---

## Performance Impact

**Expected impacts** on cluster after hardening:

| Component | Expected Change | Notes |
|-----------|-----------------|-------|
| API Server latency | +1-2% | TLS cipher suite validation |
| API Server memory | +5-10 MB | Audit logging buffers |
| Controller Manager memory | +2-5 MB | Individual SA credentials |
| Kubelet restart time | +5-10 seconds | New certificates validation |
| Audit log disk I/O | +10-20% | Depending on request volume |

**Mitigation**:
- Audit log rotation (maxage, maxsize, maxbackup)
- Async audit processing if available
- Disk provisioning for audit logs (on separate storage)

---

## Security Benefits

### Authentication & Authorization (1.2.1 - 1.2.8)
- ✅ Prevents anonymous API access
- ✅ Eliminates legacy auth methods (basic, token)
- ✅ Requires certificate-based authentication
- ✅ Enforces RBAC for fine-grained access control

### Admission Control (1.2.10)
- ✅ Enforces pod security policies
- ✅ Prevents privileged pods
- ✅ Blocks unauthorized node modifications
- ✅ Enforces resource quotas

### Network Security (1.2.11 - 1.2.15)
- ✅ Disables insecure HTTP port
- ✅ Requires modern TLS 1.2+ with strong ciphers
- ✅ Prevents downgrade attacks
- ✅ Validates server certificates

### Audit & Monitoring (1.2.17 - 1.2.20)
- ✅ Complete API activity trail
- ✅ Compliance evidence collection
- ✅ Incident investigation capability
- ✅ Anomaly detection readiness

### Encryption (1.2.25)
- ✅ Protects etcd data at rest
- ✅ Compliance with data protection regulations
- ✅ Defends against physical attacks

---

## References

- [CIS Kubernetes Benchmark](https://www.cisecurity.org/cis-benchmarks/)
- [Kubernetes API Server Security](https://kubernetes.io/docs/concepts/security/controlling-access/)
- [TLS in Kubernetes](https://kubernetes.io/docs/tasks/tls/managing-tls-in-a-cluster/)
- [Audit Logging](https://kubernetes.io/docs/tasks/debug-application-cluster/audit/)
- [Encryption at Rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/)

---

**Document Version**: 1.0  
**Last Updated**: December 9, 2025  
**Status**: ✅ Current for Kubernetes 1.34
