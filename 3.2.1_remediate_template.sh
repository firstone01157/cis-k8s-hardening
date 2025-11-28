#!/bin/bash
set -e

################################################################################
# CIS Benchmark: 3.2.1
# Title: Ensure that a log file format is configured
# Level: Level 1 - Master Node
# Remediation Script (Config-Driven with Environment Variables)
################################################################################

# --- Environment Variable Configuration ---
AUDIT_LEVEL="${AUDIT_LEVEL:-Metadata}"           # Metadata, RequestResponse
DRY_RUN="${DRY_RUN:-false}"                       # true for dry-run, false for actual changes
WAIT_FOR_API="${WAIT_FOR_API:-true}"              # Wait for API server health
API_RETRIES="${API_RETRIES:-10}"                  # API server retry attempts
API_RETRY_DELAY="${API_RETRY_DELAY:-5}"           # Delay between API retries

# From config JSON (if provided)
CONFIG_AUDIT_LEVEL="${CONFIG_AUDIT_LEVEL:-Metadata}"
CONFIG_LOG_SENSITIVE_RESOURCES="${CONFIG_LOG_SENSITIVE_RESOURCES:-true}"
CONFIG_SENSITIVE_RESOURCES="${CONFIG_SENSITIVE_RESOURCES:-}"

# --- File Paths ---
AUDIT_POLICY_FILE="/etc/kubernetes/audit-policy.yaml"
AUDIT_LOG_DIR="/var/log/kubernetes/audit"
APISERVER_CONFIG="/etc/kubernetes/manifests/kube-apiserver.yaml"

# --- Color Codes ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Configuration ---
LOG_FILE="/var/log/cis-3.2.1-remediation.log"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/cis-remediation}"

# --- Logging Function ---
log_msg() {
    local level=$1
    local msg=$2
    echo "[${level}] ${msg}" | tee -a "${LOG_FILE}"
}

# --- Banner ---
show_banner() {
    echo -e "${CYAN}"
    echo "================================================================================"
    echo "  CIS Kubernetes Benchmark 3.2.1 - Audit Policy (Config-Driven)"
    echo "================================================================================"
    echo "  AUDIT_LEVEL: ${AUDIT_LEVEL}"
    echo "  DRY_RUN: ${DRY_RUN}"
    echo "================================================================================"
    echo -e "${NC}"
}

# --- Ensure Directories Exist ---
init_directories() {
    mkdir -p "$(dirname "${LOG_FILE}")"
    mkdir -p "${AUDIT_LOG_DIR}"
    mkdir -p "${BACKUP_DIR}"
    chmod 700 "${AUDIT_LOG_DIR}"
    log_msg "INFO" "Directories initialized"
}

# --- Health Check: Wait for API Server ---
wait_for_api_server() {
    local retries=0
    
    log_msg "INFO" "Waiting for Kubernetes API Server..."
    
    while [ $retries -lt ${API_RETRIES} ]; do
        if kubectl get nodes &>/dev/null; then
            log_msg "INFO" "API Server is healthy"
            return 0
        fi
        
        retries=$((retries + 1))
        log_msg "WAIT" "API not ready (attempt $retries/${API_RETRIES}), retrying in ${API_RETRY_DELAY}s..."
        sleep ${API_RETRY_DELAY}
    done
    
    log_msg "ERROR" "API Server did not become healthy"
    return 1
}

# --- Create Audit Policy ---
create_audit_policy() {
    log_msg "INFO" "Creating audit policy file..."
    
    # Check if policy already exists
    if [ -f "${AUDIT_POLICY_FILE}" ]; then
        log_msg "PASS" "Audit policy already exists"
        return 0
    fi
    
    if [ "${DRY_RUN}" = "true" ]; then
        log_msg "DRYRUN" "Would create audit policy at ${AUDIT_POLICY_FILE}"
        return 0
    fi
    
    # Create policy based on audit level
    cat > "${AUDIT_POLICY_FILE}" << 'POLICY_EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # Log pod exec at RequestResponse level (sensitive)
  - level: RequestResponse
    verbs: ["create", "update", "patch", "delete"]
    resources:
      - group: ""
        resources: ["pods/exec", "pods/attach"]

  # Log secret access at RequestResponse level
  - level: RequestResponse
    resources:
      - group: ""
        resources: ["secrets"]
      - group: ""
        resources: ["configmaps"]

  # Audit RBAC changes
  - level: RequestResponse
    verbs: ["create", "update", "patch", "delete"]
    resources:
      - group: "rbac.authorization.k8s.io"
        resources: ["clusterroles", "clusterrolebindings", "roles", "rolebindings"]

  # Default: log at specified level
  - level: AUDIT_LEVEL_PLACEHOLDER
    omitStages:
    - RequestReceived
POLICY_EOF
    
    # Replace audit level placeholder
    sed -i "s/AUDIT_LEVEL_PLACEHOLDER/${AUDIT_LEVEL}/g" "${AUDIT_POLICY_FILE}"
    
    if [ -f "${AUDIT_POLICY_FILE}" ]; then
        log_msg "PASS" "Audit policy created successfully"
        return 0
    else
        log_msg "FAIL" "Failed to create audit policy"
        return 1
    fi
}

# --- Update Kube-APIServer with Audit Policy ---
update_apiserver() {
    log_msg "INFO" "Updating kube-apiserver configuration..."
    
    # Check if file exists
    if [ ! -f "${APISERVER_CONFIG}" ]; then
        log_msg "FAIL" "kube-apiserver.yaml not found: ${APISERVER_CONFIG}"
        return 1
    fi
    
    # Check if already configured
    if grep -Fq -- "--audit-policy-file=${AUDIT_POLICY_FILE}" "${APISERVER_CONFIG}"; then
        log_msg "PASS" "kube-apiserver already configured with audit policy"
        return 0
    fi
    
    if [ "${DRY_RUN}" = "true" ]; then
        log_msg "DRYRUN" "Would update kube-apiserver.yaml"
        return 0
    fi
    
    # Backup
    local backup_file="${BACKUP_DIR}/kube-apiserver.yaml.bak.$(date +%s)"
    cp "${APISERVER_CONFIG}" "${backup_file}"
    log_msg "INFO" "Backup created: ${backup_file}"
    
    # Add audit policy file argument if not present
    if ! grep -Fq -- "--audit-policy-file=" "${APISERVER_CONFIG}"; then
        log_msg "INFO" "Adding --audit-policy-file to kube-apiserver"
        sed -i "/  - kube-apiserver/a \    - --audit-policy-file=${AUDIT_POLICY_FILE}" "${APISERVER_CONFIG}"
    fi
    
    # Add audit log path if not present
    if ! grep -Fq -- "--audit-log-path=" "${APISERVER_CONFIG}"; then
        log_msg "INFO" "Adding --audit-log-path to kube-apiserver"
        sed -i "/  - kube-apiserver/a \    - --audit-log-path=${AUDIT_LOG_DIR}/audit.log" "${APISERVER_CONFIG}"
    fi
    
    log_msg "PASS" "kube-apiserver configuration updated"
    return 0
}

# --- Verify Audit Policy ---
verify_audit_policy() {
    log_msg "INFO" "Verifying audit policy..."
    
    # Check policy file
    if [ ! -f "${AUDIT_POLICY_FILE}" ]; then
        log_msg "FAIL" "Audit policy file not found"
        return 1
    fi
    
    # Check kube-apiserver config
    if ! grep -Fq -- "--audit-policy-file=" "${APISERVER_CONFIG}"; then
        log_msg "FAIL" "kube-apiserver not configured with audit policy"
        return 1
    fi
    
    log_msg "PASS" "Audit policy verified"
    return 0
}

################################################################################
# MAIN EXECUTION
################################################################################
main() {
    show_banner
    init_directories
    
    # Use config values if provided
    if [ -n "${CONFIG_AUDIT_LEVEL}" ]; then
        AUDIT_LEVEL="${CONFIG_AUDIT_LEVEL}"
        log_msg "INFO" "Using audit level from config: ${AUDIT_LEVEL}"
    fi
    
    # Wait for API server if enabled
    if [ "${WAIT_FOR_API}" = "true" ]; then
        if ! wait_for_api_server; then
            log_msg "ERROR" "API Server health check failed"
            exit 1
        fi
    fi
    
    # Create audit policy
    if ! create_audit_policy; then
        log_msg "ERROR" "Failed to create audit policy"
        exit 1
    fi
    
    # Update kube-apiserver
    if ! update_apiserver; then
        log_msg "ERROR" "Failed to update kube-apiserver"
        exit 1
    fi
    
    # Verify
    if ! verify_audit_policy; then
        log_msg "ERROR" "Audit policy verification failed"
        exit 1
    fi
    
    # Final Summary
    echo -e "\n${CYAN}================================================================================${NC}"
    echo -e "${GREEN}[+] SUCCESS: CIS 3.2.1 Audit Policy remediation completed${NC}"
    echo -e "    - Audit policy created: ${AUDIT_POLICY_FILE}"
    echo -e "    - Audit level: ${AUDIT_LEVEL}"
    echo -e "    - kube-apiserver configured"
    echo -e "    - Audit logs to: ${AUDIT_LOG_DIR}/audit.log"
    echo -e "${CYAN}================================================================================${NC}"
    
    log_msg "SUCCESS" "CIS 3.2.1 remediation completed"
    exit 0
}

# Execute main function
main "$@"
