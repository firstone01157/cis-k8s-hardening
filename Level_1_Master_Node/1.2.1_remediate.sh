#!/bin/bash
# CIS Benchmark 1.2.1
# Ensure that the --anonymous-auth argument is set to false
# Level: 1 - Master Node

set -euo pipefail

# 1. Resolve Python Script Absolute Path
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$CURRENT_DIR")"
HARDENER_SCRIPT="$PROJECT_ROOT/harden_manifests.py"

# Verification with fallbacks
if [ ! -f "$HARDENER_SCRIPT" ]; then
    if [ -f "$CURRENT_DIR/../harden_manifests.py" ]; then
        HARDENER_SCRIPT="$CURRENT_DIR/../harden_manifests.py"
    elif [ -f "/home/master/cis-k8s-hardening/harden_manifests.py" ]; then
        HARDENER_SCRIPT="/home/master/cis-k8s-hardening/harden_manifests.py"
    else
        echo "[ERROR] harden_manifests.py not found. Cannot proceed."
        exit 1
    fi
fi

# 2. Set Variables (Allow overrides)
VALUE=$(echo "${CONFIG_REQUIRED_VALUE:-false}" | tr -d '"')
MANIFEST_FILE="/etc/kubernetes/manifests/kube-apiserver.yaml"

echo "[INFO] Running Hardener: $HARDENER_SCRIPT"
echo "[INFO] Task: Setting --anonymous-auth to $VALUE in $MANIFEST_FILE"

# 3. Execute Python Hardener (Using = to prevent parsing errors)
python3 "$HARDENER_SCRIPT" \
    --manifest="$MANIFEST_FILE" \
    --flag="--anonymous-auth" \
    --value="$VALUE" \
    --ensure=present

# 4. Check Result & Force Reload
if [ $? -eq 0 ]; then
    echo "[FIXED] CIS 1.2.1: Successfully updated --anonymous-auth"
    # Touch manifest to force kubelet reload of static pod
    touch "$MANIFEST_FILE"
    exit 0
else
    echo "[ERROR] Failed to update --anonymous-auth"
    exit 1
fi