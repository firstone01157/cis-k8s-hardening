#!/bin/bash
# CIS Benchmark: 1.1.9
# Title: Ensure that the Container Network Interface file permissions are set to 600 or more restrictive
# Level: Level 1 - Master Node
# Remediation Script

# 1. Define Variables
CNI_DIR="/etc/cni/net.d"
MAX_PERM=600

echo "[INFO] Remediating permissions for files in $CNI_DIR..."

# 2. Pre-Check & 3. Apply Fix (Iterative)
if [ -d "$CNI_DIR" ]; then
    # We iterate and fix as needed
    find "$CNI_DIR" -maxdepth 1 -type f | while read -r l_file; do
        CURRENT_PERM=$(stat -c %a "$l_file")
        if [ "$CURRENT_PERM" -le "$MAX_PERM" ]; then
            echo "[INFO] Permissions on $l_file are already $CURRENT_PERM (<= $MAX_PERM)."
        else
            echo "[INFO] Fixing permissions on $l_file..."
            chmod "$MAX_PERM" "$l_file"
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
        CURRENT_PERM=$(stat -c %a "$l_file")
        if [ "$CURRENT_PERM" -gt "$MAX_PERM" ]; then
            echo "[ERROR] Failed to apply permissions to $l_file (Current: $CURRENT_PERM)"
            FAILED=1
        fi
    done < <(find "$CNI_DIR" -maxdepth 1 -type f)
fi

if [ "$FAILED" -eq 0 ]; then
    echo "[FIXED] Successfully verified permissions for all files in $CNI_DIR"
    exit 0
else
    exit 1
fi
