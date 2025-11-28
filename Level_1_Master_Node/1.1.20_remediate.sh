#!/bin/bash
# CIS Benchmark: 1.1.20
# Title: Ensure that the Kubernetes PKI certificate file permissions are set to 644 or more restrictive
# Level: Level 1 - Master Node
# Remediation Script

# 1. Define Variables
PKI_DIR="/etc/kubernetes/pki"
MAX_PERM=644

echo "[INFO] Remediating permissions for *.crt files in $PKI_DIR..."

# 2. Pre-Check & 3. Apply Fix (Iterative)
if [ -d "$PKI_DIR" ]; then
    find "$PKI_DIR" -name "*.crt" | while read -r l_file; do
        CURRENT_PERM=$(stat -c %a "$l_file")
        # Check if permission is greater than MAX_PERM (e.g. 666, 777)
        # Simple check: if it allows group write or other write, it's bad.
        # We enforce 644.
        if [ "$CURRENT_PERM" -ne 644 ] && [ "$CURRENT_PERM" -ne 600 ] && [ "$CURRENT_PERM" -ne 640 ] && [ "$CURRENT_PERM" -ne 444 ] && [ "$CURRENT_PERM" -ne 400 ]; then
             echo "[INFO] Fixing permissions on $l_file (Current: $CURRENT_PERM)..."
             chmod 644 "$l_file"
        else
             echo "[INFO] Permissions on $l_file are already compliant ($CURRENT_PERM)."
        fi
    done
else
    echo "[INFO] PKI directory $PKI_DIR not found. Skipping."
    exit 0
fi

# 4. Verification
FAILED=0
if [ -d "$PKI_DIR" ]; then
    while read -r l_file; do
        CURRENT_PERM=$(stat -c %a "$l_file")
        if [ "$CURRENT_PERM" -ne 644 ] && [ "$CURRENT_PERM" -ne 600 ] && [ "$CURRENT_PERM" -ne 640 ] && [ "$CURRENT_PERM" -ne 444 ] && [ "$CURRENT_PERM" -ne 400 ]; then
            echo "[ERROR] Failed to apply permissions to $l_file (Current: $CURRENT_PERM)"
            FAILED=1
        fi
    done < <(find "$PKI_DIR" -name "*.crt")
fi

if [ "$FAILED" -eq 0 ]; then
    echo "[FIXED] Successfully verified permissions for all *.crt files in $PKI_DIR"
    exit 0
else
    exit 1
fi
