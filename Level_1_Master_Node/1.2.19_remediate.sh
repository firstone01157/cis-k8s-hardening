#!/bin/bash
set -e

# CIS Benchmark: 1.2.19
# Title: Ensure that the --audit-log-maxsize argument is set to 100 or as appropriate
# Level: Level 1 - Master Node
# Remediation Script

# Configuration
CONFIG_FILE="/etc/kubernetes/manifests/kube-apiserver.yaml"
KEY="--audit-log-maxsize"
VALUE="100"
FULL_PARAM="${KEY}=${VALUE}"

echo "[INFO] Remediating ${KEY}..."

# 1. Pre-check
if grep -Fq -- "${FULL_PARAM}" "${CONFIG_FILE}"; then
    echo "[PASS] ${FULL_PARAM} is already set."
    exit 0
fi

# 2. Backup
cp "${CONFIG_FILE}" "${CONFIG_FILE}.bak.$(date +%s)"

# 3. Apply Fix
if grep -Fq -- "${KEY}" "${CONFIG_FILE}"; then
    sed -i "s|${KEY}=.*|${FULL_PARAM}|g" "${CONFIG_FILE}"
else
    sed -i "/  - kube-apiserver/a \    - ${FULL_PARAM}" "${CONFIG_FILE}"
fi

# 4. Verify
if grep -Fq -- "${FULL_PARAM}" "${CONFIG_FILE}"; then
    echo "[PASS] Successfully applied ${FULL_PARAM}"
    exit 0
else
    echo "[FAIL] Failed to apply ${FULL_PARAM}"
    exit 1
fi
