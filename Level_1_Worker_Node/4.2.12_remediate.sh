#!/bin/bash
# CIS Benchmark: 4.2.12
# Title: Ensure that the --tls-cipher-suites argument is set to strong values
# Level: Level 1 - Worker Node
# Remediation Script (Config-Driven)

set -euo pipefail

KUBELET_CONFIG=${CONFIG_FILE:-/var/lib/kubelet/config.yaml}

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

echo "[INFO] Setting tlsCipherSuites"

# Call Python helper with JSON array for cipher suites
CIPHER_SUITES='["TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256","TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256","TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305","TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384","TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305","TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384"]'

if python3 "$HELPER_SCRIPT" \
    --config "$KUBELET_CONFIG" \
    --key "tlsCipherSuites" \
    --value "$CIPHER_SUITES"; then
    echo "[INFO] Restarting kubelet..."
    if systemctl restart kubelet 2>&1; then
        sleep 2
        if systemctl is-active --quiet kubelet; then
            echo "[PASS] 4.2.12 remediation complete"
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
