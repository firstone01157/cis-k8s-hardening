#!/bin/bash
set -e

# CIS Benchmark: 1.2.20
# Title: Ensure that the --request-timeout argument is set as appropriate
# Level: Level 1 - Master Node
# Remediation Script

# Configuration
CONFIG_FILE="/etc/kubernetes/manifests/kube-apiserver.yaml"
KEY="--request-timeout"
VALUE="300s"
FULL_PARAM="${KEY}=${VALUE}"
BINARY_NAME="kube-apiserver"

echo "[INFO] Remediating ${KEY}..."

# 1. Pre-check using 'grep -F --' to handle dashes safely
if grep -Fq -- "${KEY}" "${CONFIG_FILE}"; then
    echo "[FIXED] ${KEY} is already set."
    exit 0
fi

# 2. Backup
cp "${CONFIG_FILE}" "${CONFIG_FILE}.bak.$(date +%s)"

# 3. Apply Fix using sed
if grep -Fq -- "${KEY}" "${CONFIG_FILE}"; then
    # Key exists, leave as-is (assume appropriate value)
    echo "[FIXED] ${KEY} is already set."
else
    # Key missing, insert default
    sed -i "/- ${BINARY_NAME}/a \    - ${FULL_PARAM}" "${CONFIG_FILE}"
fi

# 4. Verify
if grep -Fq -- "${KEY}" "${CONFIG_FILE}"; then
    echo "[FIXED] Successfully applied ${KEY}"
else
    echo "[ERROR] Failed to apply ${KEY}"
    exit 1
fi