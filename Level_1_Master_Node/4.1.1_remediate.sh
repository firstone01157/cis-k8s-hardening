#!/bin/bash
# CIS Benchmark: 4.1.1
# Title: Ensure that the kubelet service file permissions are set to 600 or more restrictive
# Level: Level 1 - Master Node
# Remediation Script

# 1. Define Variables
# Check both potential locations
FILE1="/etc/systemd/system/kubelet.service.d/10-kubeadm.conf"
FILE2="/etc/systemd/system/kubelet.service"
MAX_PERM=600

echo "[INFO] Remediating permissions for kubelet service files..."

# Helper function
fix_perm() {
    local l_file=$1
    if [ -e "$l_file" ]; then
        local l_mode=$(stat -c %a "$l_file")
        if [ "$l_mode" -le "$MAX_PERM" ]; then
            echo "[FIXED] Permissions on $l_file are already $l_mode (<= $MAX_PERM)."
        else
            echo "[INFO] Fixing permissions on $l_file..."
            chmod "$MAX_PERM" "$l_file"
            local l_mode_new=$(stat -c %a "$l_file")
            if [ "$l_mode_new" -le "$MAX_PERM" ]; then
                echo "[FIXED] Successfully applied permissions $MAX_PERM to $l_file"
            else
                echo "[ERROR] Failed to apply permissions to $l_file"
                return 1
            fi
        fi
    fi
}

# 2. Pre-Check & 3. Apply Fix
fix_perm "$FILE1"
fix_perm "$FILE2"

# 4. Verification
# Implicit in helper function
exit 0
