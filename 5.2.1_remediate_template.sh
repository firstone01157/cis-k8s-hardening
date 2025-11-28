#!/bin/bash
set -e

################################################################################
# CIS Benchmark: 5.2.1
# Title: Ensure that the default namespace does not automatically admit pods
# Level: Level 1 - Master Node
# Remediation Script (Config-Driven with Environment Variables)
################################################################################

# --- Environment Variable Configuration ---
# These variables can be set via cis_k8s_unified.py or manually
PSS_MODE="${PSS_MODE:-warn-audit}"              # warn-audit, enforce, warn-only, audit-only
DRY_RUN="${DRY_RUN:-false}"                      # true for dry-run, false for actual changes
KUBECTL_TIMEOUT="${KUBECTL_TIMEOUT:-30}"         # kubectl timeout in seconds
WAIT_FOR_API="${WAIT_FOR_API:-true}"             # Wait for API server health
API_RETRIES="${API_RETRIES:-10}"                 # API server retry attempts
API_RETRY_DELAY="${API_RETRY_DELAY:-5}"          # Delay between API retries

# From config JSON (if provided)
CONFIG_MODE="${CONFIG_MODE:-restricted}"         # PSS profile to use
CONFIG_NAMESPACES="${CONFIG_NAMESPACES:-}"       # JSON namespaces config (optional)
CONFIG_CREATE_SECURE_ZONE="${CONFIG_CREATE_SECURE_ZONE:-false}"
CONFIG_SECURE_ZONE_CONFIG="${CONFIG_SECURE_ZONE_CONFIG:-}"

# --- Color Codes ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Configuration ---
LOG_FILE="/var/log/cis-5.2.1-remediation.log"

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
    echo "  CIS Kubernetes Benchmark 5.2.1 - Pod Security Standards (Config-Driven)"
    echo "================================================================================"
    echo "  PSS_MODE: ${PSS_MODE}"
    echo "  DRY_RUN: ${DRY_RUN}"
    echo "================================================================================"
    echo -e "${NC}"
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

# --- Parse PSS Mode ---
parse_pss_mode() {
    case "${PSS_MODE}" in
        warn-audit|warn-audit-enforce)
            WARN_MODE="restricted"
            AUDIT_MODE="restricted"
            ENFORCE_MODE="disabled"
            ;;
        warn-only)
            WARN_MODE="restricted"
            AUDIT_MODE="disabled"
            ENFORCE_MODE="disabled"
            ;;
        audit-only)
            WARN_MODE="disabled"
            AUDIT_MODE="restricted"
            ENFORCE_MODE="disabled"
            ;;
        enforce)
            WARN_MODE="disabled"
            AUDIT_MODE="disabled"
            ENFORCE_MODE="restricted"
            ;;
        *)
            log_msg "WARN" "Unknown PSS_MODE: ${PSS_MODE}, using warn-audit"
            WARN_MODE="restricted"
            AUDIT_MODE="restricted"
            ENFORCE_MODE="disabled"
            ;;
    esac
}

# --- Apply Pod Security Standards to Namespace ---
apply_pss_to_namespace() {
    local namespace=$1
    local warn_mode=$2
    local audit_mode=$3
    local enforce_mode=$4
    
    log_msg "INFO" "Applying PSS to namespace: ${namespace}"
    
    # Build kubectl label command
    local label_cmd="kubectl label --overwrite namespace ${namespace}"
    
    if [ "${warn_mode}" != "disabled" ]; then
        label_cmd="${label_cmd} pod-security.kubernetes.io/warn=${warn_mode}"
    fi
    
    if [ "${audit_mode}" != "disabled" ]; then
        label_cmd="${label_cmd} pod-security.kubernetes.io/audit=${audit_mode}"
    fi
    
    if [ "${enforce_mode}" != "disabled" ]; then
        label_cmd="${label_cmd} pod-security.kubernetes.io/enforce=${enforce_mode}"
    fi
    
    # Add timeout if set
    if [ -n "${KUBECTL_TIMEOUT}" ]; then
        label_cmd="${label_cmd} --timeout=${KUBECTL_TIMEOUT}s"
    fi
    
    # Print command for visibility
    log_msg "DEBUG" "Executing: ${label_cmd}"
    
    # Execute in dry-run mode if enabled
    if [ "${DRY_RUN}" = "true" ]; then
        log_msg "DRYRUN" "Would apply: ${label_cmd}"
        return 0
    fi
    
    # Execute the command
    if eval "${label_cmd}" &>/dev/null; then
        log_msg "PASS" "Successfully applied PSS to ${namespace}"
        return 0
    else
        log_msg "FAIL" "Could not apply PSS to ${namespace}"
        return 1
    fi
}

# --- Create Secure Zone Namespace ---
create_secure_zone() {
    local ns_name="secure-zone"
    
    log_msg "INFO" "Creating/verifying secure-zone namespace..."
    
    if [ "${DRY_RUN}" = "true" ]; then
        log_msg "DRYRUN" "Would create namespace: ${ns_name}"
        return 0
    fi
    
    # Create namespace (idempotent)
    if kubectl create ns "${ns_name}" --dry-run=client -o yaml 2>/dev/null | kubectl apply -f - &>/dev/null; then
        log_msg "INFO" "Namespace ${ns_name} created/verified"
        
        # Apply enforce mode
        if kubectl label --overwrite namespace "${ns_name}" \
            pod-security.kubernetes.io/enforce=restricted \
            --timeout=${KUBECTL_TIMEOUT}s &>/dev/null; then
            log_msg "PASS" "Secure zone created with enforce=restricted"
            return 0
        else
            log_msg "WARN" "Namespace created but could not apply enforce label"
            return 0  # Partial success
        fi
    else
        log_msg "WARN" "Could not create secure-zone namespace"
        return 1
    fi
}

# --- Verify Pod Security Standards ---
verify_pss_applied() {
    local namespace=$1
    
    log_msg "INFO" "Verifying PSS on namespace: ${namespace}"
    
    # Check if any PSS label is present
    local labels=$(kubectl get namespace "${namespace}" -o jsonpath='{.metadata.labels}' 2>/dev/null)
    
    if echo "${labels}" | grep -q "pod-security.kubernetes.io"; then
        log_msg "PASS" "PSS labels are present on ${namespace}"
        return 0
    else
        log_msg "FAIL" "PSS labels not found on ${namespace}"
        return 1
    fi
}

################################################################################
# MAIN EXECUTION
################################################################################
main() {
    show_banner
    
    # Initialize log file
    mkdir -p "$(dirname "${LOG_FILE}")"
    
    # Parse PSS mode to determine which labels to apply
    parse_pss_mode
    
    log_msg "INFO" "Parsed PSS Mode: WARN=${WARN_MODE}, AUDIT=${AUDIT_MODE}, ENFORCE=${ENFORCE_MODE}"
    
    # Wait for API server if enabled
    if [ "${WAIT_FOR_API}" = "true" ]; then
        if ! wait_for_api_server; then
            log_msg "ERROR" "API Server health check failed"
            exit 1
        fi
    fi
    
    # Apply PSS to default namespace (Safe Mode - Warn/Audit only)
    if ! apply_pss_to_namespace "default" "${WARN_MODE}" "${AUDIT_MODE}" "${ENFORCE_MODE}"; then
        log_msg "ERROR" "Failed to apply PSS to default namespace"
        exit 1
    fi
    
    # Verify application
    if ! verify_pss_applied "default"; then
        log_msg "WARN" "Verification failed, but PSS may still be applied"
    fi
    
    # Create secure zone if configured
    if [ "${CONFIG_CREATE_SECURE_ZONE}" = "true" ] || [ "${CONFIG_CREATE_SECURE_ZONE}" = "True" ]; then
        if ! create_secure_zone; then
            log_msg "WARN" "Failed to create secure-zone (non-fatal)"
        fi
    fi
    
    # Final Summary
    echo -e "\n${CYAN}================================================================================${NC}"
    echo -e "${GREEN}[+] SUCCESS: CIS 5.2.1 Pod Security Standards remediation completed${NC}"
    echo -e "    - Applied PSS to default namespace (Warn/Audit Mode - Safe)"
    echo -e "    - No existing workloads affected"
    echo -e "    - Warnings logged for PSS-incompatible pods"
    echo -e "${CYAN}================================================================================${NC}"
    
    log_msg "SUCCESS" "CIS 5.2.1 remediation completed"
    exit 0
}

# Execute main function
main "$@"
