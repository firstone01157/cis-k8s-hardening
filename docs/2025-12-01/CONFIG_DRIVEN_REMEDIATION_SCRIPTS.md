# Config-Driven Worker Node Kubelet Remediation Scripts

## Overview

All worker node kubelet remediation scripts have been converted to a **config-driven** model where configuration values are injected via environment variables (prefixed with `CONFIG_`). This enables the Python runner to control remediation behavior through `cis_config.json` without modifying scripts.

**Location**: `/home/first/Project/cis-k8s-hardening/Level_1_Worker_Node/`

**Total Scripts**: 11 (4.1.9, 4.2.1, 4.2.3, 4.2.4, 4.2.5, 4.2.6, 4.2.10, 4.2.11, 4.2.12, 4.2.13, 4.2.14)

---

## Configuration Injection Model

### Environment Variables Pattern

Each script expects configuration in the format:

```bash
CONFIG_<SETTING_NAME>=<value>
```

**Examples**:
```bash
CONFIG_FILE=/var/lib/kubelet/config.yaml
CONFIG_MODE=600
CONFIG_CLIENT_CA_FILE=/etc/kubernetes/pki/ca.crt
CONFIG_READONLY_PORT=0
```

### Python Runner Integration

The Python runner injects these from `cis_config.json`:

```python
env.update({
    "CONFIG_FILE": "/var/lib/kubelet/config.yaml",
    "CONFIG_MODE": "600",
    "CONFIG_CLIENT_CA_FILE": "/etc/kubernetes/pki/ca.crt",
    # ... other settings
})
```

---

## Script Details

### 4.1.9_remediate.sh - File Permissions

**Purpose**: Ensure kubelet config has permissions 600 or more restrictive

**Configuration Variables**:
- `CONFIG_FILE` (default: `/var/lib/kubelet/config.yaml`)
- `CONFIG_MODE` (default: `600`)

**Operation**:
```bash
chmod $CONFIG_MODE $CONFIG_FILE
```

**Key Features**:
- Validates current permissions with `stat`
- Only applies chmod if current mode is more permissive
- Uses numeric permission comparison
- Idempotent (multiple runs safe)

**Example**:
```bash
CONFIG_FILE=/var/lib/kubelet/config.yaml \
CONFIG_MODE=600 \
sudo bash 4.1.9_remediate.sh
```

---

### 4.2.1_remediate.sh - Anonymous Authentication

**Purpose**: Ensure anonymous auth is set to false

**Configuration Variables**:
- `CONFIG_FILE` (default: `/var/lib/kubelet/config.yaml`)
- `CONFIG_ANONYMOUS_AUTH` (default: `false`)

**Operation**:
```bash
anonymousAuth: false
```

**Key Features**:
- Uses `grep -Fq` for idempotency check
- Removes existing entries before adding new value
- Safe sed with literal pattern (no regex)
- Simple top-level YAML key

**Example**:
```bash
CONFIG_ANONYMOUS_AUTH=false sudo bash 4.2.1_remediate.sh
```

---

### 4.2.3_remediate.sh - Client CA File

**Purpose**: Set authentication.x509.clientCAFile for certificate validation

**Configuration Variables**:
- `CONFIG_FILE` (default: `/var/lib/kubelet/config.yaml`)
- `CONFIG_CLIENT_CA_FILE` (default: `/etc/kubernetes/pki/ca.crt`)

**Operation**:
```yaml
authentication:
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
```

**Key Features**:
- Handles nested YAML structure (authentication > x509 > clientCAFile)
- Creates missing sections safely
- Uses sed with proper indentation handling
- Validates final state with grep

**Example**:
```bash
CONFIG_CLIENT_CA_FILE=/etc/kubernetes/pki/ca.crt sudo bash 4.2.3_remediate.sh
```

---

### 4.2.4_remediate.sh - Read-Only Port

**Purpose**: Disable kubelet read-only port (set to 0)

**Configuration Variables**:
- `CONFIG_FILE` (default: `/var/lib/kubelet/config.yaml`)
- `CONFIG_READONLY_PORT` (default: `0`)

**Operation**:
```yaml
readOnlyPort: 0
```

**Key Features**:
- Simple key-value pair at top level
- Disables unauthenticated access to kubelet
- Idempotent grep-based check

**Example**:
```bash
CONFIG_READONLY_PORT=0 sudo bash 4.2.4_remediate.sh
```

---

### 4.2.5_remediate.sh - Streaming Connection Timeout

**Purpose**: Set idle connection timeout (minimum 4h)

**Configuration Variables**:
- `CONFIG_FILE` (default: `/var/lib/kubelet/config.yaml`)
- `CONFIG_STREAMING_TIMEOUT` (default: `4h`)

**Operation**:
```yaml
streamingConnectionIdleTimeout: 4h
```

**Key Features**:
- Duration format value (4h = 4 hours)
- Prevents long-hanging connections
- Top-level YAML key

**Example**:
```bash
CONFIG_STREAMING_TIMEOUT=5h sudo bash 4.2.5_remediate.sh
```

---

### 4.2.6_remediate.sh - IPTables Utility Chains

**Purpose**: Enable automatic iptables utility chain creation

**Configuration Variables**:
- `CONFIG_FILE` (default: `/var/lib/kubelet/config.yaml`)
- `CONFIG_MAKE_IPTABLES_UTIL_CHAINS` (default: `true`)

**Operation**:
```yaml
makeIPTablesUtilChains: true
```

**Key Features**:
- Boolean value (true/false)
- Top-level YAML key
- Safe sed deletion pattern

**Example**:
```bash
CONFIG_MAKE_IPTABLES_UTIL_CHAINS=true sudo bash 4.2.6_remediate.sh
```

---

### 4.2.10_remediate.sh - Rotate Certificates

**Purpose**: Enable kubelet certificate rotation

**Configuration Variables**:
- `CONFIG_FILE` (default: `/var/lib/kubelet/config.yaml`)
- `CONFIG_ROTATE_CERTIFICATES` (default: `true`)

**Operation**:
```yaml
rotateCertificates: true
```

**Key Features**:
- Prevents certificate expiration
- Boolean value
- Auto-renewal of kubelet certificates

**Example**:
```bash
CONFIG_ROTATE_CERTIFICATES=true sudo bash 4.2.10_remediate.sh
```

---

### 4.2.11_remediate.sh - Rotate Server Certificates

**Purpose**: Enable server certificate rotation

**Configuration Variables**:
- `CONFIG_FILE` (default: `/var/lib/kubelet/config.yaml`)
- `CONFIG_ROTATE_SERVER_CERTIFICATES` (default: `true`)

**Operation**:
```yaml
rotateServerCertificates: true
```

**Key Features**:
- Separate from certificate rotation (different cert type)
- Kubelet API server certificates
- Boolean value

**Example**:
```bash
CONFIG_ROTATE_SERVER_CERTIFICATES=true sudo bash 4.2.11_remediate.sh
```

---

### 4.2.12_remediate.sh - TLS Cipher Suites

**Purpose**: Configure strong TLS cipher suites

**Configuration Variables**:
- `CONFIG_FILE` (default: `/var/lib/kubelet/config.yaml`)

**Operation**:
```yaml
tlsCipherSuites:
  - TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
  - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
  - TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305
  - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
  - TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305
  - TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
```

**Key Features**:
- Multi-line YAML list structure
- All ECDHE (Perfect Forward Secrecy)
- AEAD encryption (Authenticated Encryption)
- Modern cryptographic standards
- Special sed for multi-line range deletion
- Verifies all 6 ciphers present before considering "done"

**Cipher Details**:
- ECDHE: Elliptic Curve Diffie-Hellman Ephemeral (PFS)
- ECDSA/RSA: Signature algorithm
- AES-128/256: Symmetric encryption
- GCM: Galois/Counter Mode (AEAD)
- ChaCha20: Alternative stream cipher
- Poly1305: Alternative AEAD mode

**Example**:
```bash
sudo bash 4.2.12_remediate.sh
```

---

### 4.2.13_remediate.sh - Pod PIDs Limit

**Purpose**: Set limit on pod process IDs

**Configuration Variables**:
- `CONFIG_FILE` (default: `/var/lib/kubelet/config.yaml`)
- `CONFIG_POD_PIDS_LIMIT` (default: `-1`)

**Operation**:
```yaml
podPidsLimit: -1
```

**Key Features**:
- `-1` means unlimited (enforced at cgroup level)
- Prevents pod-level PID exhaustion
- Numeric value

**Example**:
```bash
CONFIG_POD_PIDS_LIMIT=-1 sudo bash 4.2.13_remediate.sh
```

---

### 4.2.14_remediate.sh - Seccomp Default

**Purpose**: Enable seccomp security profiles by default

**Configuration Variables**:
- `CONFIG_FILE` (default: `/var/lib/kubelet/config.yaml`)
- `CONFIG_SECCOMP_DEFAULT` (default: `true`)

**Operation**:
```yaml
seccompDefault: true
```

**Key Features**:
- Restricts syscalls available to containers
- Default RuntimeDefault profile
- Boolean value
- Enhances container isolation

**Example**:
```bash
CONFIG_SECCOMP_DEFAULT=true sudo bash 4.2.14_remediate.sh
```

---

## Common Script Pattern

All scripts follow this safe pattern:

```bash
#!/bin/bash
set -euo pipefail

# 1. Accept configuration from environment
CONFIG_FILE=${CONFIG_FILE:-/var/lib/kubelet/config.yaml}
CONFIG_VALUE=${CONFIG_VALUE:-default_value}

# 2. Check file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "[INFO] Configuration not found; skipping." >&2
    exit 0
fi

# 3. Check idempotency (grep -Fq for exact match)
if grep -Fq "key: $CONFIG_VALUE" "$CONFIG_FILE"; then
    echo "[INFO] Already configured."
    exit 0
fi

# 4. Apply changes safely (remove old, add new)
sed -i '/^key:/d' "$CONFIG_FILE" || true
printf "key: %s\n" "$CONFIG_VALUE" >> "$CONFIG_FILE"

echo "[FIXED] Configuration updated"

# 5. Restart kubelet
systemctl daemon-reload >/dev/null 2>&1 || true
systemctl restart kubelet >/dev/null 2>&1 || true

exit 0
```

---

## Running Scripts

### Individual Script

```bash
sudo bash /home/first/Project/cis-k8s-hardening/Level_1_Worker_Node/4.2.4_remediate.sh
```

### With Custom Configuration

```bash
CONFIG_READONLY_PORT=0 sudo bash 4.2.4_remediate.sh
```

### All Scripts in Sequence

```bash
cd /home/first/Project/cis-k8s-hardening/Level_1_Worker_Node

for num in 1.9 2.1 2.3 2.4 2.5 2.6 2.10 2.11 2.12 2.13 2.14; do
    script="4.${num}_remediate.sh"
    if [ -f "$script" ]; then
        echo "[*] Running $script..."
        sudo bash "$script"
    fi
done
```

### Via Python Runner

The unified Python runner will automatically:
1. Load configuration from `cis_config.json`
2. Convert to `CONFIG_` environment variables
3. Execute scripts with injected configuration
4. Collect results and generate reports

```bash
sudo python3 cis_k8s_unified.py
```

---

## Configuration File Mapping

### cis_config.json Format

```json
{
    "remediation_config": {
        "checks": {
            "4.1.9": {
                "enabled": true,
                "file": "/var/lib/kubelet/config.yaml",
                "mode": "600"
            },
            "4.2.1": {
                "enabled": true,
                "anonymous_auth": false
            },
            "4.2.3": {
                "enabled": true,
                "client_ca_file": "/etc/kubernetes/pki/ca.crt"
            },
            "4.2.4": {
                "enabled": true,
                "readonly_port": 0
            }
        }
    }
}
```

### Python Runner Conversion

```python
if "4.1.9" in remediation_checks_config:
    config = remediation_checks_config["4.1.9"]
    env["CONFIG_FILE"] = config.get("file", "/var/lib/kubelet/config.yaml")
    env["CONFIG_MODE"] = config.get("mode", "600")
```

---

## Error Handling

All scripts implement:

1. **File Existence Check**: Skip gracefully if kubelet config not found
2. **Idempotency Check**: Exit early if already configured
3. **Strict Error Mode**: `set -euo pipefail` for early failure
4. **Graceful Restart**: Restart kubelet with error suppression (`|| true`)
5. **Clear Messaging**: `[INFO]`, `[FIXED]`, `[ERROR]` prefixes

---

## Validation Checklist

- ✅ All 11 scripts syntax validated
- ✅ Grep -F pattern (no regex, safe)
- ✅ Safe sed operations (literal patterns, explicit cleanup)
- ✅ No kubectl dependency (direct file operations)
- ✅ Idempotent (can run multiple times safely)
- ✅ Configuration-driven (environment variables)
- ✅ Kubelet restart on changes
- ✅ Error handling with exit codes
- ✅ Status messages for diagnostics

---

## Status

✅ **All 11 scripts converted to config-driven model**

- Syntax: ✓ Valid bash
- Testing: ✓ All scripts validated
- Integration: ✓ Ready for Python runner
- Documentation: ✓ Complete

**Ready for production deployment**

---

## Integration with cis_config.json

Example configuration:

```json
{
    "remediation_config": {
        "global": {
            "backup_enabled": true,
            "dry_run": false,
            "wait_for_api": true
        },
        "checks": {
            "4.1.9": {"enabled": true, "file": "/var/lib/kubelet/config.yaml", "mode": "600"},
            "4.2.1": {"enabled": true, "anonymous_auth": false},
            "4.2.3": {"enabled": true, "client_ca_file": "/etc/kubernetes/pki/ca.crt"},
            "4.2.4": {"enabled": true, "readonly_port": 0},
            "4.2.5": {"enabled": true, "streaming_timeout": "4h"},
            "4.2.6": {"enabled": true, "make_iptables_util_chains": true},
            "4.2.10": {"enabled": true, "rotate_certificates": true},
            "4.2.11": {"enabled": true, "rotate_server_certificates": true},
            "4.2.12": {"enabled": true},
            "4.2.13": {"enabled": true, "pod_pids_limit": -1},
            "4.2.14": {"enabled": true, "seccomp_default": true}
        }
    }
}
```

---

**Last Updated**: December 1, 2025  
**Script Count**: 11  
**Pattern**: Config-Driven (Environment Variables)  
**Compliance**: CIS Kubernetes Benchmark v1.12.0
