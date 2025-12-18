# CIS Master Node Remediation Scripts - Updated

## Overview
All 7 Master Node remediation scripts have been rewritten to properly integrate with `harden_manifests.py` using correct argparse syntax.

## Key Changes

### Problem Fixed
**Before:** Scripts failed with argparse errors when passing flags containing dashes:
```bash
# BAD - argparse interprets --anonymous-auth as a new flag
python3 script.py --flag --anonymous-auth
```

**After:** All scripts now use `=` syntax to prevent parsing errors:
```bash
# GOOD - argparse correctly treats the entire string as a value
python3 script.py --flag="--anonymous-auth"
```

### Template Applied to All 7 Scripts

Each script now follows this structure:

```bash
#!/bin/bash
# 1. Resolve Python Script Absolute Path
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$CURRENT_DIR")"
HARDENER_SCRIPT="$PROJECT_ROOT/harden_manifests.py"

# Fallback paths if not found
if [ ! -f "$HARDENER_SCRIPT" ]; then
    # Try relative paths
    # Try absolute path
fi

# 2. Set Variables (Allow overrides via CONFIG_REQUIRED_VALUE)
VALUE=$(echo "${CONFIG_REQUIRED_VALUE:-[DEFAULT]}" | tr -d '"')
MANIFEST_FILE="[MANIFEST_PATH]"

# 3. Execute Python Hardener (Using = to prevent parsing errors)
python3 "$HARDENER_SCRIPT" \
    --manifest="$MANIFEST_FILE" \
    --flag="[FLAG_NAME]" \
    --value="$VALUE" \
    --ensure=present

# 4. Check Result & Force Reload
if [ $? -eq 0 ]; then
    touch "$MANIFEST_FILE"  # Trigger kubelet reload
    exit 0
else
    exit 1
fi
```

## Updated Scripts

### 1. 1.2.1_remediate.sh
- **Control**: --anonymous-auth=false
- **Manifest**: `/etc/kubernetes/manifests/kube-apiserver.yaml`
- **Default Value**: false
- **Status**: ✅ Complete

### 2. 1.2.7_remediate.sh
- **Control**: --authorization-mode includes Node
- **Manifest**: `/etc/kubernetes/manifests/kube-apiserver.yaml`
- **Default Value**: Node
- **Status**: ✅ Complete

### 3. 1.2.9_remediate.sh
- **Control**: --enable-admission-plugins includes EventRateLimit
- **Manifest**: `/etc/kubernetes/manifests/kube-apiserver.yaml`
- **Default Value**: EventRateLimit
- **Status**: ✅ Complete

### 4. 1.2.11_remediate.sh
- **Control**: --enable-admission-plugins includes AlwaysPullImages
- **Manifest**: `/etc/kubernetes/manifests/kube-apiserver.yaml`
- **Default Value**: AlwaysPullImages
- **Status**: ✅ Complete

### 5. 1.2.30_remediate.sh
- **Control**: --service-account-extend-token-expiration=false
- **Manifest**: `/etc/kubernetes/manifests/kube-apiserver.yaml`
- **Default Value**: false
- **Status**: ✅ Complete

### 6. 1.3.6_remediate.sh
- **Control**: --feature-gates includes RotateKubeletServerCertificate=true
- **Manifest**: `/etc/kubernetes/manifests/kube-controller-manager.yaml`
- **Default Value**: RotateKubeletServerCertificate=true
- **Status**: ✅ Complete

### 7. 1.4.1_remediate.sh
- **Control**: --profiling=false
- **Manifest**: `/etc/kubernetes/manifests/kube-scheduler.yaml`
- **Default Value**: false
- **Status**: ✅ Complete

## Argument Handling Details

### Proper Syntax Used
```bash
python3 "$HARDENER_SCRIPT" \
    --manifest="$MANIFEST_FILE" \        # Uses = syntax
    --flag="$FLAG_NAME" \                # Uses = syntax - prevents argparse errors
    --value="$VALUE" \                   # Uses = syntax
    --ensure=present                     # Uses = syntax
```

### Why This Works
- **Double-dash flags with hyphens** (`--anonymous-auth`, `--enable-admission-plugins`, etc.) are safely passed as values using `--flag="--anonymous-auth"`
- argparse receives the entire string as a single value, not as a separate flag
- No special escaping needed
- Works with all flag names, including those containing multiple hyphens

## Variables and Defaults

Each script respects the `CONFIG_REQUIRED_VALUE` environment variable:
```bash
VALUE=$(echo "${CONFIG_REQUIRED_VALUE:-false}" | tr -d '"')
```

- Uses the provided value if `CONFIG_REQUIRED_VALUE` is set
- Falls back to sensible defaults (false, Node, EventRateLimit, etc.)
- Strips quotes from environment variable values to prevent double-quoting

## Path Resolution

All scripts implement robust path resolution:
1. **Primary**: `$CURRENT_DIR/../harden_manifests.py` (one level up from Level_1_Master_Node)
2. **Secondary**: `$CURRENT_DIR/../harden_manifests.py` (relative fallback)
3. **Tertiary**: `/home/master/cis-k8s-hardening/harden_manifests.py` (absolute fallback)

This ensures scripts work regardless of:
- Directory depth
- Deployment location
- How the scripts are invoked (directly, via absolute path, etc.)

## Manifest Reload

After successful execution:
```bash
touch "$MANIFEST_FILE"
```

This triggers kubelet's file watch to automatically reload the static pod, without requiring:
- Manual pod restart
- systemd restart
- Manual kubelet reload

## Deployment

All 7 scripts are ready to deploy to:
```
/home/master/cis-k8s-hardening/Level_1_Master_Node/
```

Ensure `harden_manifests.py` is also deployed to:
```
/home/master/cis-k8s-hardening/
```

## Testing

To verify proper operation:
```bash
cd /home/master/cis-k8s-hardening

# Test path resolution by running from different directories
cd /tmp && bash /home/master/cis-k8s-hardening/Level_1_Master_Node/1.2.1_remediate.sh

# Verify the manifest was modified
grep -A2 "anonymous-auth" /etc/kubernetes/manifests/kube-apiserver.yaml
```

## Summary

✅ All 7 scripts now use correct argparse syntax with `=` operator
✅ Flags containing dashes are safely passed as values
✅ Environment variable overrides supported
✅ Robust path resolution with fallbacks
✅ Automatic manifest reload via kubelet file watch
✅ Ready for production deployment
