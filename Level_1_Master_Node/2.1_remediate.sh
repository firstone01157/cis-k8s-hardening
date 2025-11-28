#!/bin/bash
set -e

# CIS Benchmark: 2.1
# Title: Ensure that the --cert-file and --key-file arguments are set as appropriate
# Level: Level 1 - Master Node
# Remediation Script

# Configuration
CONFIG_FILE="/etc/kubernetes/manifests/etcd.yaml"
BINARY_NAME="etcd"
KEY1="--cert-file"
VALUE1="/etc/kubernetes/pki/etcd/server.crt"
FULL_PARAM1="${KEY1}=${VALUE1}"
KEY2="--key-file"
VALUE2="/etc/kubernetes/pki/etcd/server.key"
FULL_PARAM2="${KEY2}=${VALUE2}"

echo "[INFO] Remediating ${KEY1} and ${KEY2}..."

# 1. Pre-check
if grep -Fq -- "${FULL_PARAM1}" "${CONFIG_FILE}" && grep -Fq -- "${FULL_PARAM2}" "${CONFIG_FILE}"; then
    echo "[PASS] Both parameters are already set."
    exit 0
fi

# 2. Backup
cp "${CONFIG_FILE}" "${CONFIG_FILE}.bak.$(date +%s)"

# 3. Apply Fix for Parameter 1 (--cert-file)
if grep -Fq -- "${KEY1}" "${CONFIG_FILE}"; then
    sed -i "s|${KEY1}=.*|${FULL_PARAM1}|g" "${CONFIG_FILE}"
else
    sed -i "/  - ${BINARY_NAME}/a \    - ${FULL_PARAM1}" "${CONFIG_FILE}"
fi

# 4. Apply Fix for Parameter 2 (--key-file)
if grep -Fq -- "${KEY2}" "${CONFIG_FILE}"; then
    sed -i "s|${KEY2}=.*|${FULL_PARAM2}|g" "${CONFIG_FILE}"
else
    sed -i "/  - ${BINARY_NAME}/a \    - ${FULL_PARAM2}" "${CONFIG_FILE}"
fi

# 5. Verify both parameters
if grep -Fq -- "${FULL_PARAM1}" "${CONFIG_FILE}" && grep -Fq -- "${FULL_PARAM2}" "${CONFIG_FILE}"; then
    echo "[PASS] Successfully applied both ${KEY1} and ${KEY2}"
    exit 0
else
    echo "[FAIL] Failed to apply one or both parameters"
    exit 1
fi
