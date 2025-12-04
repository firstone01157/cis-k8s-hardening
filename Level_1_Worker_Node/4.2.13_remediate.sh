#!/bin/bash
# CIS Benchmark: 4.2.13
# Title: Ensure that a limit is set on pod PIDs
# Level: Level 1 - Worker Node
# Remediation Script (Config-Driven)

set -euo pipefail

KUBELET_CONFIG=${CONFIG_FILE:-/var/lib/kubelet/config.yaml}
POD_PIDS_LIMIT=${CONFIG_POD_PIDS_LIMIT:--1}

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

echo "[INFO] Setting podPidsLimit to $POD_PIDS_LIMIT"

# Call Python helper
if python3 "$HELPER_SCRIPT" \
    --config "$KUBELET_CONFIG" \
    --key "podPidsLimit" \
    --value "$POD_PIDS_LIMIT"; then
    if [ "${CIS_NO_RESTART:-false}" = "true" ]; then
        echo "[INFO] Restart skipped (Batch Mode)"
    else
        echo "[INFO] Restarting kubelet..."
        if systemctl restart kubelet 2>&1; then
            sleep 2
            if systemctl is-active --quiet kubelet; then
                echo "[PASS] 4.2.13 remediation complete"
                exit 0
            else
                echo "[FAIL] kubelet not running after restart"
                exit 1
            fi
        else
            echo "[FAIL] kubelet restart failed"
            exit 1
        fi
    fi
else
    echo "[FAIL] Failed to update configuration"
    exit 1
fi
