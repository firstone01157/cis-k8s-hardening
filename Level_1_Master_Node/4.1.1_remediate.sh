#!/bin/bash
# CIS Benchmark: 4.1.1
# Title: Ensure that the kubelet service file permissions are set to 600 or more restrictive
# Remediation Script (Dynamic Path Detection)

set -euo pipefail

# 1. Dynamic Path Detection (หาไฟล์ตัวจริง ไม่ว่าจะอยู่ /lib หรือ /etc)
# ดึง Path จาก systemd โดยตรง เพื่อความชัวร์ 100%
SERVICE_FILE=$(systemctl show -p FragmentPath kubelet.service | cut -d= -f2)
DROPIN_FILE="/etc/systemd/system/kubelet.service.d/10-kubeadm.conf"
MAX_PERM=600

echo "[INFO] Detected kubelet service file at: $SERVICE_FILE"

# Helper function
fix_perm() {
    local l_file=$1
    
    # Check if file exists
    if [ -z "$l_file" ] || [ ! -e "$l_file" ]; then
        echo "[WARN] File not found or empty path: '$l_file' (Skipping)"
        return
    fi

    # Check current permissions
    local l_mode=$(stat -c %a "$l_file")
    
    # Logic: ถ้า permission มากกว่า 600 (เช่น 644) ต้องแก้
    # Note: Bash string comparison works for simple octal like 644 > 600
    if [ "$l_mode" -gt "$MAX_PERM" ]; then
        echo "[INFO] Fixing permissions on $l_file (Current: $l_mode -> Target: $MAX_PERM)..."
        chmod "$MAX_PERM" "$l_file"
        
        # Verify
        local l_mode_new=$(stat -c %a "$l_file")
        if [ "$l_mode_new" -le "$MAX_PERM" ]; then
            echo "[FIXED] Successfully applied permissions $MAX_PERM"
        else
            echo "[FAIL] Failed to apply permissions"
            exit 1
        fi
    else
        echo "[PASS] Permissions on $l_file are compliant ($l_mode <= $MAX_PERM)."
    fi
}

# 2. Apply Fixes
fix_perm "$SERVICE_FILE"
fix_perm "$DROPIN_FILE"

# 3. Reload Systemd (Best Practice after touching service files)
echo "[INFO] Reloading systemd daemon..."
systemctl daemon-reload

exit 0