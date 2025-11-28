#!/bin/bash
# CIS Benchmark: 1.1.7
# Title: Ensure that the etcd pod specification file permissions are set to 600 or more restrictive
# Level: Level 1 - Master Node
# Remediation Script

# 1. Define Variables
CONFIG_FILE="/etc/kubernetes/manifests/etcd.yaml"
MAX_PERM=600

echo "[INFO] Remediating permissions for $CONFIG_FILE..."

# 2. Pre-Check (Idempotency)
if [ -e "$CONFIG_FILE" ]; then
    CURRENT_PERM=$(stat -c %a "$CONFIG_FILE")
    if [ "$CURRENT_PERM" -le "$MAX_PERM" ]; then
        echo "[FIXED] Permissions on $CONFIG_FILE are already $CURRENT_PERM (<= $MAX_PERM)."
        exit 0
    fi
else
    echo "[INFO] $CONFIG_FILE not found. Skipping."
    exit 0
fi

# 3. Apply Fix
chmod "$MAX_PERM" "$CONFIG_FILE"

# 4. Verification & Output
CURRENT_PERM=$(stat -c %a "$CONFIG_FILE")
if [ "$CURRENT_PERM" -le "$MAX_PERM" ]; then
    echo "[FIXED] Successfully applied permissions $MAX_PERM to $CONFIG_FILE"
else
    echo "[ERROR] Failed to apply permissions to $CONFIG_FILE"
    exit 1
fi
