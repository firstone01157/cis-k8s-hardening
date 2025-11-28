#!/bin/bash
# CIS Benchmark: 1.2.11
# Title: Ensure that the --enable-admission-plugins argument is set to a value that does not include AlwaysAdmit
# Level: Level 1 - Master Node
# Remediation Script

# 1. Define Variables
CONFIG_FILE="/etc/kubernetes/manifests/kube-apiserver.yaml"
KEY="--enable-admission-plugins"
BAD_VALUE="AlwaysAdmit"

echo "[INFO] Remediating $KEY to remove $BAD_VALUE..."

# 2. Pre-Check
if ! grep -q "$KEY=.*$BAD_VALUE" "$CONFIG_FILE"; then
    echo "[FIXED] $KEY does not include $BAD_VALUE."
    exit 0
fi

# 3. Apply Fix
# Remove AlwaysAdmit from comma-separated list
# Handle: AlwaysAdmit, | ,AlwaysAdmit | AlwaysAdmit
sed -i "s/$BAD_VALUE,//g" "$CONFIG_FILE"
sed -i "s/,$BAD_VALUE//g" "$CONFIG_FILE"
# If it was the only value, we might have empty value now.
# We can check if line ends with = and remove it or warn.
# But usually there are other plugins.

# 4. Verification
if ! grep -q "$KEY=.*$BAD_VALUE" "$CONFIG_FILE"; then
    echo "[FIXED] Successfully removed $BAD_VALUE from $KEY"
    exit 0
else
    echo "[ERROR] Failed to remove $BAD_VALUE from $KEY"
    exit 1
fi