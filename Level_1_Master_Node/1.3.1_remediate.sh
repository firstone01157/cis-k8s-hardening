#!/bin/bash
set -e

# CIS Benchmark: 1.3.1
# Title: Ensure that the --terminated-pod-gc-threshold argument is set as appropriate
# Level: Level 1 - Master Node
# Remediation Script - Config-Driven

# --- CONFIG (from environment, with defaults) ---
THRESHOLD="${CONFIG_THRESHOLD:-12500}"
CONFIG_FILE="${CONFIG_CONFIG_FILE:-/etc/kubernetes/manifests/kube-controller-manager.yaml}"

BINARY_NAME="kube-controller-manager"
KEY="--terminated-pod-gc-threshold"
VALUE="$THRESHOLD"
FULL_PARAM="${KEY}=${VALUE}"

echo "[INFO] Remediating CIS 1.3.1: Terminated Pod GC Threshold"
echo "[INFO] TARGET_THRESHOLD=$THRESHOLD"
echo "[INFO] CONFIG_FILE=$CONFIG_FILE"

# 1. Pre-check: Does the parameter already have the correct value?
if grep -Fq -- "${FULL_PARAM}" "${CONFIG_FILE}"; then
    echo "[PASS] ${FULL_PARAM} is already set correctly."
    exit 0
fi

# 2. Backup the original file
BACKUP_FILE="${CONFIG_FILE}.bak.$(date +%s)"
cp "${CONFIG_FILE}" "${BACKUP_FILE}"
echo "[INFO] Backup created: ${BACKUP_FILE}"

# 3. Apply fix
if grep -Fq -- "${KEY}" "${CONFIG_FILE}"; then
    echo "[INFO] Updating existing ${KEY} parameter..."
    sed -i "s|${KEY}=.*|${FULL_PARAM}|g" "${CONFIG_FILE}"
else
    echo "[INFO] Adding new ${KEY} parameter..."
    sed -i "/  - ${BINARY_NAME}/a \    - ${FULL_PARAM}" "${CONFIG_FILE}"
fi

# 4. Verify the fix was applied
if grep -Fq -- "${FULL_PARAM}" "${CONFIG_FILE}"; then
    echo "[PASS] Successfully applied ${FULL_PARAM}"
    echo "[INFO] The kubelet will now garbage collect terminated pods after $THRESHOLD pods have terminated."
    echo "[INFO] Configuration will take effect after the next kube-controller-manager restart."
    exit 0
else
    echo "[FAIL] Failed to apply ${FULL_PARAM}"
    echo "[INFO] Rolling back to backup: ${BACKUP_FILE}"
    cp "${BACKUP_FILE}" "${CONFIG_FILE}"
    exit 1
fi