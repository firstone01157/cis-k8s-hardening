#!/bin/bash
set -e

# CIS Benchmark: 1.3.6
# Title: Ensure that the RotateKubeletServerCertificate argument is set to true
# Level: Level 1 - Master Node
# Remediation Script

# Configuration
CONFIG_FILE="/etc/kubernetes/manifests/kube-controller-manager.yaml"
BINARY_NAME="kube-controller-manager"
KEY="--feature-gates"
VALUE="RotateKubeletServerCertificate=true"
FULL_PARAM="${KEY}=${VALUE}"

echo "[INFO] Remediating ${KEY}..."

# 1. Pre-check
if grep -Fq -- "${VALUE}" "${CONFIG_FILE}"; then
    echo "[PASS] ${FULL_PARAM} is already set."
    exit 0
fi

# 2. Backup
cp "${CONFIG_FILE}" "${CONFIG_FILE}.bak.$(date +%s)"

# 3. Apply Fix
if grep -Fq -- "${KEY}" "${CONFIG_FILE}"; then
    sed -i "s|${KEY}=\(.*\)|${KEY}=\1,${VALUE}|g" "${CONFIG_FILE}"
else
    sed -i "/  - ${BINARY_NAME}/a \    - ${FULL_PARAM}" "${CONFIG_FILE}"
fi

# 4. Verify
if grep -Fq -- "${VALUE}" "${CONFIG_FILE}"; then
    echo "[PASS] Successfully applied ${FULL_PARAM}"
    exit 0
else
    echo "[FAIL] Failed to apply ${FULL_PARAM}"
    exit 1
fi