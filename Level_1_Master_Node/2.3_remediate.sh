#!/bin/bash
# CIS Benchmark: 2.3
# Title: Ensure that the --auto-tls argument is not set to true
# Level: Level 1 - Master Node
# Remediation Script

# 1. Define Variables
CONFIG_FILE="/etc/kubernetes/manifests/etcd.yaml"
KEY="--auto-tls"
BAD_VALUE="true"

echo "[INFO] Remediating $KEY..."

# 2. Pre-Check
if ! grep -q "$KEY=true" "$CONFIG_FILE"; then
    echo "[FIXED] $KEY is not set to true."
    exit 0
fi

# 3. Apply Fix
# Set to false if present as true
sed -i "s/$KEY=true/$KEY=false/g" "$CONFIG_FILE"

# 4. Verification
if ! grep -q "$KEY=true" "$CONFIG_FILE"; then
    echo "[FIXED] Successfully remediated $KEY"
else
    echo "[ERROR] Failed to remediate $KEY"
    exit 1
fi
