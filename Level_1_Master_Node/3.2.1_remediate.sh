#!/bin/bash
set -e

# CIS Benchmark: 3.2.1
# Title: Ensure that a system audit record is generated
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
POLICY_FILE="${CONFIG_AUDIT_POLICY_PATH:-/etc/kubernetes/audit-policy.yaml}"
LOG_FILE="${CONFIG_AUDIT_LOG_PATH:-/var/log/k8s-audit.log}"
MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"

echo "[INFO] Remediating 3.2.1 (Audit Policy)..."

# 2. Create Audit Policy File
echo "[INFO] Creating audit policy at ${POLICY_FILE}..."
cat > "${POLICY_FILE}" << 'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata
  omitStages:
  - RequestReceived
  resources:
  - group: ""
    resources:
    - secrets
    - configmaps
  - group: "apps"
    resources:
    - deployments
    - statefulsets
  - group: ""
    resources:
    - pods
    - pods/exec
    - pods/attach
  verbs:
  - create
  - update
  - patch
  - delete
- level: RequestResponse
  omitStages:
  - RequestReceived
  resources:
  - group: ""
    resources:
    - secrets
  verbs:
  - get
  - list
- level: Metadata
  omitStages:
  - RequestReceived
EOF

chmod 600 "${POLICY_FILE}"
chown root:root "${POLICY_FILE}"
echo "[PASS] Audit policy created at ${POLICY_FILE}"

# 3. Backup Manifest
BACKUP_FILE="${MANIFEST}.bak.$(date +%s)"
cp "${MANIFEST}" "${BACKUP_FILE}"
echo "[INFO] Backup created: ${BACKUP_FILE}"

# 4. Function to add/update flag in kube-apiserver manifest
add_flag() {
    local key=$1
    local value=$2
    local file=$3
    
    if grep -q "^\s*- ${key}=" "$file"; then
        sed -i "s|^\(\s*\)- ${key}=.*|\1- ${key}=${value}|g" "$file"
        echo "[INFO] Updated flag: ${key}"
    else
        sed -i "/^\s*- kube-apiserver$/a\\    - ${key}=${value}" "$file"
        echo "[INFO] Added flag: ${key}"
    fi
}

# 5. Add audit flags to kube-apiserver manifest
add_flag "--audit-policy-file" "${POLICY_FILE}" "${MANIFEST}"
add_flag "--audit-log-path" "${LOG_FILE}" "${MANIFEST}"
add_flag "--audit-log-maxage" "30" "${MANIFEST}"
add_flag "--audit-log-maxbackup" "10" "${MANIFEST}"
add_flag "--audit-log-maxsize" "100" "${MANIFEST}"

echo "[PASS] Audit flags added to kube-apiserver manifest"

# 6. Verify policy file exists and is readable
if [ -f "${POLICY_FILE}" ] && [ -r "${POLICY_FILE}" ]; then
    echo "[PASS] Audit policy file is properly configured"
else
    echo "[FAIL] Audit policy file verification failed"
    exit 1
fi

echo "[PASS] Audit policy and kube-apiserver manifest remediation complete."
exit 0