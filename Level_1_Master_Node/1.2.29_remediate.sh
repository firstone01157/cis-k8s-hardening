#!/bin/bash
set -e

# CIS Benchmark: 1.2.29
# Title: Ensure that the --tls-cipher-suites argument is set as appropriate
# Level: Level 1 - Master Node
# Remediation Script

# --- CONFIG ---
CONFIG_FILE="/etc/kubernetes/manifests/kube-apiserver.yaml"
BINARY_NAME="kube-apiserver"
KEY="--tls-cipher-suites"
VALUE="TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305"
FULL_PARAM="${KEY}=${VALUE}"

echo "[INFO] Remediating ${KEY}..."

# 1. Pre-check
if grep -Fq -- "${KEY}=" "${CONFIG_FILE}"; then
    echo "[PASS] ${KEY} is already set."
    exit 0
fi

# 2. Backup
cp "${CONFIG_FILE}" "${CONFIG_FILE}.bak.$(date +%s)"

# 3. Apply Fix
sed -i "/  - ${BINARY_NAME}/a \    - ${FULL_PARAM}" "${CONFIG_FILE}"

# 4. Verify
if grep -Fq -- "${KEY}=" "${CONFIG_FILE}"; then
    echo "[PASS] Successfully applied ${KEY}"
    exit 0
else
    echo "[FAIL] Failed to apply ${KEY}"
    exit 1
fi