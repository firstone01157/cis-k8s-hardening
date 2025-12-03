#!/bin/bash
# CIS Benchmark: 4.2.3
# Title: Ensure that the --client-ca-file argument is set as appropriate
# Level: Level 1 - Worker Node
# Remediation Script (Config-Driven)

set -euo pipefail

KUBELET_CONFIG=${CONFIG_FILE:-/var/lib/kubelet/config.yaml}
CLIENT_CA_FILE=${CONFIG_CLIENT_CA_FILE:-/etc/kubernetes/pki/ca.crt}

# Determine project root and helper script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
HELPER_SCRIPT="$PROJECT_ROOT/kubelet_config_manager.py"

# Fallback if running from root
if [ ! -f "$HELPER_SCRIPT" ]; then
    HELPER_SCRIPT="./kubelet_config_manager.py"
fi

if [ ! -f "$KUBELET_CONFIG" ]; then
    echo "[FAIL] Config file not found: $KUBELET_CONFIG"
    exit 1
fi

if [ ! -f "$HELPER_SCRIPT" ]; then
    echo "[FAIL] Python helper not found at $HELPER_SCRIPT"
    exit 1
fi

echo "[INFO] Setting authentication.x509.clientCAFile to $CLIENT_CA_FILE"

# Call Python helper
if python3 "$HELPER_SCRIPT" \
    --config "$KUBELET_CONFIG" \
    --key "authentication.x509.clientCAFile" \
    --value "$CLIENT_CA_FILE"; then
    echo "[INFO] Restarting kubelet..."
    if systemctl restart kubelet 2>&1; then
        sleep 2
        if systemctl is-active --quiet kubelet; then
            echo "[PASS] 4.2.3 remediation complete"
            exit 0
        else
            echo "[FAIL] kubelet not running after restart"
            exit 1
        fi
    else
        echo "[FAIL] kubelet restart failed"
        exit 1
    fi
else
    echo "[FAIL] Failed to update configuration"
    exit 1
fi
