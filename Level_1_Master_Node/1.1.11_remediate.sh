#!/bin/bash
# CIS Benchmark: 1.1.11
# Title: Ensure that the etcd data directory permissions are set to 700 or more restrictive
# Level: Level 1 - Master Node
# Remediation Script

# 1. Define Variables
# Try to detect etcd data dir, default to /var/lib/etcd
ETCD_DATA_DIR=$(ps -ef | grep etcd | grep -- --data-dir | sed 's/.*--data-dir[= ]\([^ ]*\).*/\1/')
if [ -z "$ETCD_DATA_DIR" ]; then
    ETCD_DATA_DIR="/var/lib/etcd"
fi

# Sanitize ETCD_DATA_DIR to remove any leading/trailing quotes
ETCD_DATA_DIR=$(echo "$ETCD_DATA_DIR" | sed 's/^["\x27]//;s/["\x27]$//')

MAX_PERM=700

echo "[INFO] Remediating permissions for $ETCD_DATA_DIR..."

# 2. Pre-Check
if [ -d "$ETCD_DATA_DIR" ]; then
    CURRENT_PERM=$(stat -c %a "$ETCD_DATA_DIR")
    if [ "$CURRENT_PERM" -le "$MAX_PERM" ]; then
        echo "[FIXED] Permissions on $ETCD_DATA_DIR are already $CURRENT_PERM (<= $MAX_PERM)."
        exit 0
    fi
else
    echo "[INFO] Etcd data directory $ETCD_DATA_DIR not found. Skipping."
    exit 0
fi

# 3. Apply Fix
chmod "$MAX_PERM" "$ETCD_DATA_DIR"

# 4. Verification
CURRENT_PERM=$(stat -c %a "$ETCD_DATA_DIR")
if [ "$CURRENT_PERM" -le "$MAX_PERM" ]; then
    echo "[FIXED] Successfully applied permissions $MAX_PERM to $ETCD_DATA_DIR"
else
    echo "[ERROR] Failed to apply permissions to $ETCD_DATA_DIR"
    exit 1
fi
