#!/bin/bash
set -e

# CIS Benchmark: 1.2.7
# Title: Ensure that the --authorization-mode argument includes Node
# Level: Level 1 - Master Node
# Remediation Script

# Configuration
CONFIG_FILE="/etc/kubernetes/manifests/kube-apiserver.yaml"
KEY="--authorization-mode"
VALUE="Node"
BINARY_NAME="kube-apiserver"

echo "[INFO] Remediating ${KEY}..."

# 1. Pre-check using 'grep -F --' to handle dashes safely
if grep -Fq -- "${VALUE}" "${CONFIG_FILE}"; then
    echo "[FIXED] ${KEY} includes ${VALUE}."
    exit 0
fi

# 2. Backup
cp "${CONFIG_FILE}" "${CONFIG_FILE}.bak.$(date +%s)"

# 3. Apply Fix using sed
if grep -Fq -- "${KEY}" "${CONFIG_FILE}"; then
    # Key exists, append value to comma-separated list
    sed -i "s|${KEY}=|&${VALUE},|" "${CONFIG_FILE}"
else
    # Key missing, insert with default Node,RBAC
    sed -i "/- ${BINARY_NAME}/a \    - ${KEY}=Node,RBAC" "${CONFIG_FILE}"
fi

# 4. Verify
if grep -Fq -- "${VALUE}" "${CONFIG_FILE}"; then
    echo "[FIXED] Successfully applied ${KEY} includes ${VALUE}"
else
    echo "[ERROR] Failed to apply ${KEY}"
    exit 1
fi