#!/bin/bash
# CIS Benchmark: 1.1.19
# Title: Ensure that the Kubernetes PKI directory and file ownership is set to root:root
# Level: Level 1 - Master Node
# Remediation Script

# 1. Define Variables
PKI_DIR="/etc/kubernetes/pki"
OWNER="root:root"

echo "[INFO] Remediating ownership for files in $PKI_DIR..."

# 2. Pre-Check & 3. Apply Fix (Recursive)
if [ -d "$PKI_DIR" ]; then
    # Find files not owned by root:root
    BAD_FILES=$(find "$PKI_DIR" ! -user root -o ! -group root)
    if [ -z "$BAD_FILES" ]; then
        echo "[FIXED] All files in $PKI_DIR are already owned by $OWNER."
        exit 0
    else
        echo "[INFO] Found files with incorrect ownership. Fixing..."
        chown -R "$OWNER" "$PKI_DIR"
    fi
else
    echo "[INFO] PKI directory $PKI_DIR not found. Skipping."
    exit 0
fi

# 4. Verification
BAD_FILES=$(find "$PKI_DIR" ! -user root -o ! -group root)
if [ -z "$BAD_FILES" ]; then
    echo "[FIXED] Successfully verified ownership for all files in $PKI_DIR"
    exit 0
else
    echo "[ERROR] Failed to apply ownership to some files in $PKI_DIR"
    exit 1
fi
