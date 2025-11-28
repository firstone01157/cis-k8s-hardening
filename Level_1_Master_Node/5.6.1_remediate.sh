#!/bin/bash
set -e

# CIS Benchmark: 5.6.1
# Title: Create administrative boundaries between resources using namespaces
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
ADMIN_NS="${CONFIG_ADMIN_NAMESPACE:-secure-zone}"

echo "[INFO] Remediating 5.6.1 (Administrative Boundaries)..."

# 2. Perform Action (Idempotent)
# Check if namespace exists
if kubectl get ns "${ADMIN_NS}" >/dev/null 2>&1; then
    echo "[PASS] Namespace ${ADMIN_NS} already exists."
    exit 0
fi

# Create if missing
if kubectl create ns "${ADMIN_NS}"; then
    echo "[PASS] Successfully created namespace ${ADMIN_NS}."
else
    echo "[FAIL] Failed to create namespace ${ADMIN_NS}."
    exit 1
fi

# 3. Verify Result
if kubectl get ns "${ADMIN_NS}" >/dev/null 2>&1; then
    echo "[PASS] Namespace ${ADMIN_NS} verification successful."
    exit 0
else
    echo "[FAIL] Namespace ${ADMIN_NS} verification failed."
    exit 1
fi