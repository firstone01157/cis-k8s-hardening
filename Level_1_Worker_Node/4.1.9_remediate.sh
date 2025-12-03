#!/bin/bash
# CIS Benchmark: 4.1.9
# Title: Ensure that the kubelet configuration file has permissions set to 600 or more restrictive
# Level: Level 1 - Worker Node
# Remediation Script (Config-Driven)

set -euo pipefail

CONFIG_FILE=${CONFIG_FILE:-/var/lib/kubelet/config.yaml}
CONFIG_MODE=${CONFIG_FILE_MODE:-600}

# Determine project root and helper script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
HELPER_SCRIPT="$PROJECT_ROOT/kubelet_config_manager.py"

# Fallback if running from root
if [ ! -f "$HELPER_SCRIPT" ]; then
    HELPER_SCRIPT="./kubelet_config_manager.py"
fi

if [ ! -f "$HELPER_SCRIPT" ]; then
    echo "[FAIL] Python helper not found at $HELPER_SCRIPT"
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "[FAIL] Config file not found: $CONFIG_FILE"
    exit 1
fi

# Set file permissions
chmod "$CONFIG_MODE" "$CONFIG_FILE"

# Verify
if [ "$(stat -c '%a' "$CONFIG_FILE")" = "$CONFIG_MODE" ]; then
    echo "[PASS] 4.1.9 remediation complete"
    exit 0
else
    echo "[FAIL] Failed to set permissions"
    exit 1
fi
