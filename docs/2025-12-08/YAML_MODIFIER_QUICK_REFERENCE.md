# Python YAML Modifier - Quick Reference

## Overview
A production-ready Python module for safe Kubernetes manifest modification without `sed`.

## Installation

The module is already in your project:
```bash
/home/first/Project/cis-k8s-hardening/yaml_safe_modifier.py
```

No pip install needed - uses only Python standard library.

## Quick Start

### From Bash Script

```bash
#!/bin/bash

# Set up paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_HELPER="$SCRIPT_DIR/yaml_safe_modifier.py"
MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"

# Add a flag
python3 "$PYTHON_HELPER" \
  --action add \
  --manifest "$MANIFEST" \
  --container kube-apiserver \
  --flag "--kubelet-certificate-authority" \
  --value "/etc/kubernetes/pki/ca.crt"

# Check if flag exists
python3 "$PYTHON_HELPER" \
  --action check \
  --manifest "$MANIFEST" \
  --container kube-apiserver \
  --flag "--kubelet-certificate-authority" \
  --value "/etc/kubernetes/pki/ca.crt"

# Get flag value
python3 "$PYTHON_HELPER" \
  --action get_value \
  --manifest "$MANIFEST" \
  --container kube-apiserver \
  --flag "--kubelet-certificate-authority"

# Remove flag
python3 "$PYTHON_HELPER" \
  --action remove \
  --manifest "$MANIFEST" \
  --container kube-apiserver \
  --flag "--kubelet-certificate-authority"
```

### From Python Code

```python
from yaml_safe_modifier import YAMLSafeModifier

# Create modifier instance
modifier = YAMLSafeModifier()

manifest = "/etc/kubernetes/manifests/kube-apiserver.yaml"
container = "kube-apiserver"
flag = "--kubelet-certificate-authority"
value = "/etc/kubernetes/pki/ca.crt"

# Add flag
if modifier.add_flag_to_manifest(manifest, container, flag, value):
    print(f"Successfully added {flag}")
else:
    print(f"Failed to add {flag} - check logs")

# Check if flag exists with value
if modifier.flag_exists_in_manifest(manifest, container, flag, value):
    print(f"{flag}={value} is set correctly")

# Get current value
current_value = modifier.get_flag_value(manifest, container, flag)
print(f"Current value: {current_value}")
```

## Common Tasks

### Add a New Flag

**Bash:**
```bash
python3 "$PYTHON_HELPER" --action add \
  --manifest /etc/kubernetes/manifests/kube-apiserver.yaml \
  --container kube-apiserver \
  --flag "--kubelet-certificate-authority" \
  --value "/etc/kubernetes/pki/ca.crt"
```

**Python:**
```python
modifier.add_flag_to_manifest(
    manifest="/etc/kubernetes/manifests/kube-apiserver.yaml",
    container="kube-apiserver",
    flag="--kubelet-certificate-authority",
    value="/etc/kubernetes/pki/ca.crt"
)
```

### Update Existing Flag

**Bash:**
```bash
python3 "$PYTHON_HELPER" --action update \
  --manifest /etc/kubernetes/manifests/kube-apiserver.yaml \
  --container kube-apiserver \
  --flag "--kubelet-certificate-authority" \
  --value "/etc/kubernetes/pki/ca-new.crt"
```

**Python:**
```python
modifier.update_flag_in_manifest(
    manifest="/etc/kubernetes/manifests/kube-apiserver.yaml",
    container="kube-apiserver",
    flag="--kubelet-certificate-authority",
    new_value="/etc/kubernetes/pki/ca-new.crt"
)
```

### Verify Flag Is Set

**Bash:**
```bash
# Just check existence
python3 "$PYTHON_HELPER" --action check \
  --manifest /etc/kubernetes/manifests/kube-apiserver.yaml \
  --container kube-apiserver \
  --flag "--kubelet-certificate-authority"

# Check with specific value
python3 "$PYTHON_HELPER" --action check \
  --manifest /etc/kubernetes/manifests/kube-apiserver.yaml \
  --container kube-apiserver \
  --flag "--kubelet-certificate-authority" \
  --value "/etc/kubernetes/pki/ca.crt"
```

**Python:**
```python
# Check existence only
if modifier.flag_exists_in_manifest(manifest, "kube-apiserver", "--kubelet-certificate-authority"):
    print("Flag found")

# Check with specific value
if modifier.flag_exists_in_manifest(manifest, "kube-apiserver", "--kubelet-certificate-authority", 
                                   expected_value="/etc/kubernetes/pki/ca.crt"):
    print("Flag found with expected value")
```

### Extract Flag Value

**Bash:**
```bash
VALUE=$(python3 "$PYTHON_HELPER" --action get_value \
  --manifest /etc/kubernetes/manifests/kube-apiserver.yaml \
  --container kube-apiserver \
  --flag "--kubelet-certificate-authority")

echo "Current value: $VALUE"
```

**Python:**
```python
value = modifier.get_flag_value(
    manifest="/etc/kubernetes/manifests/kube-apiserver.yaml",
    container="kube-apiserver",
    flag="--kubelet-certificate-authority"
)
print(f"Flag value: {value}")
```

### Remove Flag

**Bash:**
```bash
python3 "$PYTHON_HELPER" --action remove \
  --manifest /etc/kubernetes/manifests/kube-apiserver.yaml \
  --container kube-apiserver \
  --flag "--kubelet-certificate-authority"
```

**Python:**
```python
modifier.remove_flag_from_manifest(
    manifest="/etc/kubernetes/manifests/kube-apiserver.yaml",
    container="kube-apiserver",
    flag="--kubelet-certificate-authority"
)
```

## Return Codes

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Success | Operation completed successfully |
| 1 | Failure | Check logs at `/var/log/cis-remediation.log` |
| 2 | Invalid Arguments | Check flag names and manifest path |
| 3 | File Not Found | Manifest path is incorrect |

## Logging

All operations are logged to:
```bash
/var/log/cis-remediation.log
```

View recent logs:
```bash
tail -20 /var/log/cis-remediation.log
tail -f /var/log/cis-remediation.log  # Follow in real-time
```

Log levels:
- `INFO` - Successful operations
- `WARNING` - Unusual but recoverable conditions
- `ERROR` - Failures (with auto-restore attempt)
- `DEBUG` - Detailed operation information

## Backup & Recovery

### Automatic Backups

Backups are created automatically before modification:
```
/var/backups/cis-remediation/TIMESTAMP_cis/kube-apiserver.yaml.bak
```

Example:
```
/var/backups/cis-remediation/20250205-143022-cis/kube-apiserver.yaml.bak
```

### Manual Restore

```bash
# Find latest backup
LATEST=$(find /var/backups/cis-remediation -name "*.bak" -type f | sort | tail -1)
echo "Latest backup: $LATEST"

# Restore it
sudo cp "$LATEST" /etc/kubernetes/manifests/kube-apiserver.yaml

# Verify
sudo grep "kubelet-certificate-authority" /etc/kubernetes/manifests/kube-apiserver.yaml
```

## Error Handling

### Common Errors

**Error: "Manifest file not found"**
- Check file path is absolute: `/etc/kubernetes/manifests/kube-apiserver.yaml`
- Verify file exists: `ls -la /etc/kubernetes/manifests/kube-apiserver.yaml`
- Check permissions: `stat /etc/kubernetes/manifests/kube-apiserver.yaml`

**Error: "Container 'kube-apiserver' not found in manifest"**
- Verify container name is correct (case-sensitive)
- Check manifest structure: `grep "name:" /etc/kubernetes/manifests/kube-apiserver.yaml`
- Ensure it's a valid Kubernetes YAML

**Error: "Failed to parse manifest"**
- Check YAML syntax: `python3 -c "import yaml; yaml.safe_load(open('manifest.yaml'))"`
- Look for invalid indentation
- Check for unprintable characters: `file /etc/kubernetes/manifests/kube-apiserver.yaml`

## Performance Tips

1. **Batch Operations**: Make multiple changes in one script execution
2. **Avoid Repeated Reads**: Extract values once and reuse them
3. **Logging Level**: Set to ERROR for production to reduce I/O
4. **Manifest Size**: Script handles files up to 10MB efficiently

## Integration Examples

### With CIS 1.2.5 Remediation

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_HELPER="$SCRIPT_DIR/yaml_safe_modifier.py"

# Remediate
python3 "$PYTHON_HELPER" --action add \
  --manifest /etc/kubernetes/manifests/kube-apiserver.yaml \
  --container kube-apiserver \
  --flag "--kubelet-certificate-authority" \
  --value "/etc/kubernetes/pki/ca.crt"

# Verify
if python3 "$PYTHON_HELPER" --action check \
  --manifest /etc/kubernetes/manifests/kube-apiserver.yaml \
  --container kube-apiserver \
  --flag "--kubelet-certificate-authority" \
  --value "/etc/kubernetes/pki/ca.crt"; then
    echo "✓ Remediation successful"
    exit 0
else
    echo "✗ Remediation failed"
    exit 1
fi
```

### With Parallel Remediation

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_HELPER="$SCRIPT_DIR/yaml_safe_modifier.py"
MANIFEST=/etc/kubernetes/manifests/kube-apiserver.yaml

# Run multiple modifications
python3 "$PYTHON_HELPER" --action add \
  --manifest "$MANIFEST" \
  --container kube-apiserver \
  --flag "--kubelet-certificate-authority" \
  --value "/etc/kubernetes/pki/ca.crt" &

python3 "$PYTHON_HELPER" --action add \
  --manifest "$MANIFEST" \
  --container kube-apiserver \
  --flag "--audit-log-maxage" \
  --value "30" &

# Wait for all
wait
echo "All modifications complete"
```

## Testing

### Basic Test

```bash
# Test the module directly
cd /home/first/Project/cis-k8s-hardening
python3 yaml_safe_modifier.py

# Check output
# Should show test manifest created and operations tested
```

### Integration Test

```bash
# Create test environment
mkdir -p /tmp/test-manifests
cp /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/test-manifests/

# Run modifications
python3 /home/first/Project/cis-k8s-hardening/yaml_safe_modifier.py \
  --action add \
  --manifest /tmp/test-manifests/kube-apiserver.yaml \
  --container kube-apiserver \
  --flag "--test-flag" \
  --value "test-value"

# Verify
grep "test-flag" /tmp/test-manifests/kube-apiserver.yaml
```

## API Reference

### YAMLSafeModifier Class

**Constructor:**
```python
YAMLSafeModifier(log_level="INFO")
```

**Methods:**

| Method | Parameters | Returns | Purpose |
|--------|-----------|---------|---------|
| `add_flag_to_manifest` | manifest, container, flag, value | bool | Add new flag |
| `update_flag_in_manifest` | manifest, container, flag, new_value | bool | Update existing flag |
| `remove_flag_from_manifest` | manifest, container, flag | bool | Remove flag |
| `flag_exists_in_manifest` | manifest, container, flag, expected_value=None | bool | Check existence |
| `get_flag_value` | manifest, container, flag | str or None | Extract value |
| `create_backup` | manifest_path | bool | Create backup |
| `restore_from_backup` | manifest_path | bool | Restore from backup |

## Support

For issues, check:
1. Log file: `/var/log/cis-remediation.log`
2. Syntax: `python3 -m py_compile yaml_safe_modifier.py`
3. Permissions: `ls -la /etc/kubernetes/manifests/`
4. Documentation: `SED_FIX_DOCUMENTATION.md`

---

**Last Updated:** 2025-02-05  
**Version:** 1.0  
**Status:** Production Ready
