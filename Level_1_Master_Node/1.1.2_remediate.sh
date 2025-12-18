#!/bin/bash
# CIS Benchmark: 1.1.2
# Title: Ensure that the API server pod specification file ownership is set to root:root
# Level: Level 1 - Master Node
# Remediation Script

# 1. Define Variables
CONFIG_FILE="/etc/kubernetes/manifests/kube-apiserver.yaml"
OWNER="root:root"

# Sanitize CONFIG_FILE to remove any leading/trailing quotes
CONFIG_FILE=$(echo "$CONFIG_FILE" | sed 's/^["\x27]//;s/["\x27]$//')

echo "[INFO] Remediating ownership for $CONFIG_FILE..."

# 2. Pre-Check (Idempotency)
if [ -e "$CONFIG_FILE" ]; then
    CURRENT_OWNER=$(stat -c "%U:%G" "$CONFIG_FILE")
    if [ "$CURRENT_OWNER" = "$OWNER" ]; then
        echo "[FIXED] Ownership on $CONFIG_FILE is already $CURRENT_OWNER."
        exit 0
    fi
else
    echo "[INFO] $CONFIG_FILE not found. Skipping."
    exit 0
fi

# 3. Apply Fix
chown "$OWNER" "$CONFIG_FILE"

# 4. Verification & Output
CURRENT_OWNER=$(stat -c "%U:%G" "$CONFIG_FILE")
if [ "$CURRENT_OWNER" = "$OWNER" ]; then
    echo "[FIXED] Successfully applied ownership $OWNER to $CONFIG_FILE"
else
    echo "[ERROR] Failed to apply ownership to $CONFIG_FILE"
    exit 1
fi
