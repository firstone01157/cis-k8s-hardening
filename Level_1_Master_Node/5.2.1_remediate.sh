#!/bin/bash
set -e

# CIS Benchmark: 5.2.1-5.2.12
# Title: Pod Security Standards - Restrict container admission to restricted policy
# Level: Level 1 - Master Node
# Remediation Script

# Explicitly define kubeconfig
export KUBECONFIG=/etc/kubernetes/admin.conf

echo "[INFO] Using Kubeconfig: $KUBECONFIG"

# --- Helper Function: Wait for API ---
wait_for_api() {
    echo "[INFO] Waiting for API Server to be ready (Timeout: 60s)..."
    local retries=12
    local count=0

    while [ $count -lt $retries ]; do
        if kubectl get nodes >/dev/null 2>&1; then
            echo "[INFO] API Server is ONLINE."
            return 0
        fi
        echo "[WAIT] API Server not ready... ($((count*5))s)"
        sleep 5
        count=$((count+1))
    done
    echo "[FAIL] API Server did not recover within 60 seconds. Aborting."
    exit 1
}

# --- Execution ---
echo "[INFO] Starting remediation..."

# 1. Check API Health FIRST
wait_for_api

# --- CONFIG (Injected from JSON via Python Runner) ---
SAFE_NS="${CONFIG_SAFE_MODE_NAMESPACE:-default}"
SECURE_NS="${CONFIG_SECURE_NAMESPACE:-secure-zone}"

echo "[INFO] Remediating Pod Security Standards..."

# 2. Apply 'Warn' & 'Audit' to Safe Namespace (Default)
# This meets the requirement "at least one policy mechanism in place" without breaking apps
echo "[INFO] Applying Warn/Audit mode to namespace: ${SAFE_NS}"
if kubectl label --overwrite ns "${SAFE_NS}" \
    pod-security.kubernetes.io/warn=restricted \
    pod-security.kubernetes.io/audit=restricted >/dev/null 2>&1; then
    echo "[PASS] Applied safe labels to ${SAFE_NS}."
else
    echo "[FAIL] Failed to apply labels to ${SAFE_NS}."
    exit 1
fi

# 3. Handle Secure Namespace (Idempotent)
# Check if namespace exists before creating
if kubectl get ns "${SECURE_NS}" >/dev/null 2>&1; then
    echo "[INFO] Namespace ${SECURE_NS} already exists. Skipping creation."
else
    echo "[INFO] Creating namespace ${SECURE_NS}..."
    if kubectl create ns "${SECURE_NS}"; then
        echo "[PASS] Successfully created namespace ${SECURE_NS}."
    else
        echo "[FAIL] Failed to create namespace ${SECURE_NS}."
        exit 1
    fi
fi

# 4. Apply 'Enforce' to Secure Namespace
# This proves capability to enforce strict policies
echo "[INFO] Enforcing Restricted policy on: ${SECURE_NS}"
if kubectl label --overwrite ns "${SECURE_NS}" \
    pod-security.kubernetes.io/enforce=restricted >/dev/null 2>&1; then
    echo "[PASS] Applied strict enforcement to ${SECURE_NS}."
else
    echo "[FAIL] Failed to apply enforcement label to ${SECURE_NS}."
    exit 1
fi

# 5. Verify Result
echo "[INFO] Verifying Pod Security Standards configuration..."

# Verify warn label on default
if kubectl get ns "${SAFE_NS}" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/warn}' 2>/dev/null | grep -q "restricted"; then
    echo "[PASS] Verification: ${SAFE_NS} has warn label."
else
    echo "[FAIL] Verification: ${SAFE_NS} missing warn label."
    exit 1
fi

# Verify enforce label on secure-zone
if kubectl get ns "${SECURE_NS}" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null | grep -q "restricted"; then
    echo "[PASS] Verification: ${SECURE_NS} has enforce label."
else
    echo "[FAIL] Verification: ${SECURE_NS} missing enforce label."
    exit 1
fi

echo "[PASS] Pod Security Standards remediation complete."
exit 0
