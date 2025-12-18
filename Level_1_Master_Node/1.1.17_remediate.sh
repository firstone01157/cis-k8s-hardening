#!/bin/bash
# CIS Benchmark: 1.1.17
# Title: Ensure that the controller-manager.conf file permissions are set to 600 or more restrictive
# Level: Level 1 - Master Node
# Remediation Script

# 1. Define Variables
CONFIG_FILE="/etc/kubernetes/controller-manager.conf"
MAX_PERM=600

# Sanitize CONFIG_FILE to remove any leading/trailing quotes
CONFIG_FILE=$(echo "$CONFIG_FILE" | sed 's/^["\x27]//;s/["\x27]$//')

echo "[INFO] Remediating permissions for $CONFIG_FILE..."

# 2. Pre-Check
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

# 4. Verification
CURRENT_PERM=$(stat -c %a "$CONFIG_FILE")
if [ "$CURRENT_PERM" -le "$MAX_PERM" ]; then
    echo "[FIXED] Successfully applied permissions $MAX_PERM to $CONFIG_FILE"
else
    echo "[ERROR] Failed to apply permissions to $CONFIG_FILE"
    exit 1
fi
