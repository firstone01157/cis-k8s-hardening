#!/bin/bash
# CIS Benchmark: 1.2.3
# Title: Ensure that the --token-auth-file argument is not set
# Level: Level 1 - Master Node
# Remediation Script

# 1. Define Variables
CONFIG_FILE="/etc/kubernetes/manifests/kube-apiserver.yaml"
KEY="--token-auth-file"

echo "[INFO] Remediating $KEY..."

# 2. Pre-Check
if ! grep -q "$KEY" "$CONFIG_FILE"; then
    echo "[FIXED] $KEY is not set."
    exit 0
fi

# 3. Apply Fix
sed -i "/$KEY/d" "$CONFIG_FILE"

# 4. Verification
if ! grep -q "$KEY" "$CONFIG_FILE"; then
    echo "[FIXED] Successfully removed $KEY"
else
    echo "[ERROR] Failed to remove $KEY"
    exit 1
fi