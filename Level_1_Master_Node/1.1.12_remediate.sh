#!/bin/bash
# CIS Benchmark: 1.1.12
# Title: Ensure that the etcd data directory ownership is set to etcd:etcd
# Level: Level 1 - Master Node
# Remediation Script

# 1. Define Variables
ETCD_DATA_DIR=$(ps -ef | grep etcd | grep -- --data-dir | sed 's/.*--data-dir[= ]\([^ ]*\).*/\1/')
if [ -z "$ETCD_DATA_DIR" ]; then
    ETCD_DATA_DIR="/var/lib/etcd"
fi
OWNER="etcd:etcd"

echo "[INFO] Remediating ownership for $ETCD_DATA_DIR..."

# Check if etcd user exists
if ! id -u etcd >/dev/null 2>&1; then
    echo "[INFO] User etcd not found. Skipping."
    exit 0
fi

# 2. Pre-Check
if [ -d "$ETCD_DATA_DIR" ]; then
    CURRENT_OWNER=$(stat -c "%U:%G" "$ETCD_DATA_DIR")
    if [ "$CURRENT_OWNER" = "$OWNER" ]; then
        echo "[FIXED] Ownership on $ETCD_DATA_DIR is already $CURRENT_OWNER."
        exit 0
    fi
else
    echo "[INFO] Etcd data directory $ETCD_DATA_DIR not found. Skipping."
    exit 0
fi

# 3. Apply Fix
chown "$OWNER" "$ETCD_DATA_DIR"

# 4. Verification
CURRENT_OWNER=$(stat -c "%U:%G" "$ETCD_DATA_DIR")
if [ "$CURRENT_OWNER" = "$OWNER" ]; then
    echo "[FIXED] Successfully applied ownership $OWNER to $ETCD_DATA_DIR"
else
    echo "[ERROR] Failed to apply ownership to $ETCD_DATA_DIR"
    exit 1
fi