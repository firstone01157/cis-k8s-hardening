#!/bin/bash
# CIS Benchmark: 1.1.10
# Title: Ensure that the Container Network Interface file ownership is set to root:root
# Level: Level 1 - Master Node
# Remediation Script

# 1. Define Variables
CNI_DIR="/etc/cni/net.d"
OWNER="root:root"

echo "[INFO] Remediating ownership for files in $CNI_DIR..."

# 2. Pre-Check & 3. Apply Fix (Iterative)
if [ -d "$CNI_DIR" ]; then
    find "$CNI_DIR" -maxdepth 1 -type f | while read -r l_file; do
        CURRENT_OWNER=$(stat -c "%U:%G" "$l_file")
        if [ "$CURRENT_OWNER" = "$OWNER" ]; then
            echo "[INFO] Ownership on $l_file is already $CURRENT_OWNER."
        else
            echo "[INFO] Fixing ownership on $l_file..."
            chown "$OWNER" "$l_file"
        fi
    done
else
    echo "[INFO] CNI directory $CNI_DIR not found. Skipping."
    exit 0
fi

# 4. Verification & Output
FAILED=0
if [ -d "$CNI_DIR" ]; then
    while read -r l_file; do
        CURRENT_OWNER=$(stat -c "%U:%G" "$l_file")
        if [ "$CURRENT_OWNER" != "$OWNER" ]; then
            echo "[ERROR] Failed to apply ownership to $l_file (Current: $CURRENT_OWNER)"
            FAILED=1
        fi
    done < <(find "$CNI_DIR" -maxdepth 1 -type f)
fi

if [ "$FAILED" -eq 0 ]; then
    echo "[FIXED] Successfully verified ownership for all files in $CNI_DIR"
    exit 0
else
    exit 1
fi
