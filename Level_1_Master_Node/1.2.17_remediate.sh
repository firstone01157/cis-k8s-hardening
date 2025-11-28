#!/bin/bash
set -e

# CIS Benchmark: 1.2.17
# Title: Ensure that the --audit-log-maxage argument is set to 30 or as appropriate
# Level: Level 1 - Master Node
# Remediation Script

# Configuration
CONFIG_FILE="/etc/kubernetes/manifests/kube-apiserver.yaml"
KEY="--audit-log-maxage"
VALUE="30"
FULL_PARAM="${KEY}=${VALUE}"

echo "[INFO] Remediating ${KEY}..."

# 1. Pre-check
if grep -Fq -- "${FULL_PARAM}" "${CONFIG_FILE}"; then
    echo "[PASS] ${FULL_PARAM} is already set."
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
    sed -i "/  - kube-apiserver/a \    - ${FULL_PARAM}" "${CONFIG_FILE}" ||
    sed -i "/  - kube-controller-manager/a \    - ${FULL_PARAM}" "${CONFIG_FILE}" ||
    sed -i "/  - kube-scheduler/a \    - ${FULL_PARAM}" "${CONFIG_FILE}"
fi

# 4. Verify
if grep -Fq -- "${FULL_PARAM}" "${CONFIG_FILE}"; then
    echo "[PASS] Successfully applied ${FULL_PARAM}"
    exit 0
else
    echo "[FAIL] Failed to apply ${FULL_PARAM}"
    exit 1
fi