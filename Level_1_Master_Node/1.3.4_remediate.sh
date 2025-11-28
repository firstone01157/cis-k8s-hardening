#!/bin/bash
set -e

# CIS Benchmark: 1.3.4
# Title: Ensure that the --service-account-private-key-file argument is set as appropriate
# Level: Level 1 - Master Node
# Remediation Script

# Configuration
CONFIG_FILE="/etc/kubernetes/manifests/kube-controller-manager.yaml"
KEY="--service-account-private-key-file"
VALUE="/etc/kubernetes/pki/sa.key"
FULL_PARAM="${KEY}=${VALUE}"
BINARY_NAME="kube-controller-manager"

echo "[INFO] Remediating ${KEY}..."

# 1. Pre-check using 'grep -F --' to handle dashes safely
if grep -Fq -- "${FULL_PARAM}" "${CONFIG_FILE}"; then
    echo "[FIXED] ${FULL_PARAM} is already set."
    exit 0
fi

# 2. Backup
cp "${CONFIG_FILE}" "${CONFIG_FILE}.bak.$(date +%s)"

# 3. Apply Fix using sed
if grep -Fq -- "${KEY}" "${CONFIG_FILE}"; then
    # Case A: Key exists, update it (using | delimiter)
    sed -i "s|${KEY}=.*|${FULL_PARAM}|g" "${CONFIG_FILE}"
else
    # Case B: Key missing, append inside 'command:' block with 4-space indent
    sed -i "/- ${BINARY_NAME}/a \    - ${FULL_PARAM}" "${CONFIG_FILE}"
fi

# 4. Verify
if grep -Fq -- "${FULL_PARAM}" "${CONFIG_FILE}"; then
    echo "[FIXED] Successfully applied ${FULL_PARAM}"
else
    echo "[ERROR] Failed to apply ${FULL_PARAM}"
    exit 1
fi