#!/bin/bash
set -e

# CIS Benchmark: 1.2.5
# Title: Ensure that the --kubelet-client-certificate and --kubelet-client-key arguments are set as appropriate
# Level: Level 1 - Master Node
# Remediation Script

# Configuration
CONFIG_FILE="/etc/kubernetes/manifests/kube-apiserver.yaml"
KEY1="--kubelet-client-certificate"
VALUE1="/etc/kubernetes/pki/apiserver-kubelet-client.crt"
FULL_PARAM1="${KEY1}=${VALUE1}"
KEY2="--kubelet-client-key"
VALUE2="/etc/kubernetes/pki/apiserver-kubelet-client.key"
FULL_PARAM2="${KEY2}=${VALUE2}"
BINARY_NAME="kube-apiserver"

echo "[INFO] Remediating ${KEY1} and ${KEY2}..."

# Backup
cp "${CONFIG_FILE}" "${CONFIG_FILE}.bak.$(date +%s)"

# Process KEY1
if grep -Fq -- "${FULL_PARAM1}" "${CONFIG_FILE}"; then
    echo "[FIXED] ${FULL_PARAM1} is already set."
else
    if grep -Fq -- "${KEY1}" "${CONFIG_FILE}"; then
        sed -i "s|${KEY1}=.*|${FULL_PARAM1}|g" "${CONFIG_FILE}"
    else
        sed -i "/- ${BINARY_NAME}/a \    - ${FULL_PARAM1}" "${CONFIG_FILE}"
    fi
fi

# Process KEY2
if grep -Fq -- "${FULL_PARAM2}" "${CONFIG_FILE}"; then
    echo "[FIXED] ${FULL_PARAM2} is already set."
else
    if grep -Fq -- "${KEY2}" "${CONFIG_FILE}"; then
        sed -i "s|${KEY2}=.*|${FULL_PARAM2}|g" "${CONFIG_FILE}"
    else
        sed -i "/- ${BINARY_NAME}/a \    - ${FULL_PARAM2}" "${CONFIG_FILE}"
    fi
fi

# Verify
if grep -Fq -- "${FULL_PARAM1}" "${CONFIG_FILE}" && grep -Fq -- "${FULL_PARAM2}" "${CONFIG_FILE}"; then
    echo "[FIXED] Successfully applied both parameters"
else
    echo "[ERROR] Failed to apply one or both parameters"
    exit 1
fi