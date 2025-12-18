#!/bin/bash
################################################################################
# CIS Kubernetes Benchmark 1.2.5 Remediation (REFACTORED)
# Ensure that the --kubelet-certificate-authority argument is set as appropriate
# 
# Description:
#   The kubelet should verify TLS connections using the cluster's certificate
#   authority. This is set via the --kubelet-certificate-authority flag in the
#   API server manifest.
#
# Features:
# - Python-based YAML modification (avoids sed delimiter conflicts)
# - Auto-Detection: Automatically detects CA certificate from multiple paths
# - Safe Failover: Skips remediation gracefully if CA not found (exit 0)
# - Backup & Recovery: Automatic backup with restore on failure
# 
# Impact: Low - Manifest modification, static pod auto-restart
# Kubernetes Version: 1.20+
# 
# Author: DevSecOps Team
# Date: 2025-12-08
################################################################################

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_HELPER="$SCRIPT_DIR/scripts/yaml_safe_modifier.py"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
ENDC='\033[0m'

# Configuration
MANIFEST_DIR="/etc/kubernetes/manifests"
API_SERVER_MANIFEST="$MANIFEST_DIR/kube-apiserver.yaml"
LOG_FILE="/var/log/cis-remediation.log"
BACKUP_DIR="/var/backups/kubernetes/$(date +%Y%m%d_%H%M%S)_cis"

# Batch mode flag (if CIS_NO_RESTART=true, don't move the file)
CIS_NO_RESTART="${CIS_NO_RESTART:-false}"

# CA certificate search paths (in order of preference)
CA_CERT_PATHS=(
    "/etc/kubernetes/pki/ca.crt"
    "/etc/kubernetes/ssl/ca.pem"
    "/etc/kubernetes/pki/ca.pem"
    "/etc/ssl/certs/kubernetes/ca.crt"
    "/var/lib/kubernetes/ca.crt"
)

################################################################################
# Logging Functions
################################################################################

log_info() {
    echo -e "${CYAN}[INFO]${ENDC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${ENDC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${ENDC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${ENDC} $1" | tee -a "$LOG_FILE"
}

################################################################################
# Auto-Detect CA Certificate Function
################################################################################

detect_ca_certificate() {
    local detected_path=""
    
    log_info "Auto-detecting CA certificate..."
    
    # Search through predefined paths
    for path in "${CA_CERT_PATHS[@]}"; do
        if [[ -f "$path" ]]; then
            detected_path="$path"
            log_success "CA certificate found at: $detected_path"
            echo "$detected_path"
            return 0
        else
            log_info "Not found at: $path"
        fi
    done
    
    # If no certificate found, return empty string for safe failover
    log_warning "CA Certificate not found in any standard location"
    return 1
}

################################################################################
# Backup Function
################################################################################

backup_manifest() {
    mkdir -p "$BACKUP_DIR"
    if cp "$API_SERVER_MANIFEST" "$BACKUP_DIR/kube-apiserver.yaml.bak"; then
        log_success "Backup created: $BACKUP_DIR/kube-apiserver.yaml.bak"
        return 0
    else
        log_error "Failed to create backup of $API_SERVER_MANIFEST"
        return 1
    fi
}

################################################################################
# Python Helper Function - Safe YAML Modification
################################################################################

call_python_modifier() {
    """Call Python helper for safe YAML modification (avoids sed delimiter issues)"""
    local operation="$1"
    local manifest="$2"
    local container="$3"
    local flag="$4"
    local value="${5:-}"
    
    # Call Python helper
    python3 << EOF
import sys
sys.path.insert(0, '$SCRIPT_DIR')

from yaml_safe_modifier import YAMLSafeModifier

modifier = YAMLSafeModifier(verbose=False)

if "$operation" == "add":
    result = modifier.add_flag_to_manifest('$manifest', '$container', '$flag', '$value' if '$value' else None)
    sys.exit(0 if result else 1)
elif "$operation" == "update":
    result = modifier.update_flag_in_manifest('$manifest', '$container', '$flag', '$value')
    sys.exit(0 if result else 1)
elif "$operation" == "remove":
    result = modifier.remove_flag_from_manifest('$manifest', '$container', '$flag')
    sys.exit(0 if result else 1)
elif "$operation" == "check":
    result = modifier.flag_exists_in_manifest('$manifest', '$flag', '$value' if '$value' else None)
    sys.exit(0 if result else 1)
elif "$operation" == "get_value":
    value = modifier.get_flag_value('$manifest', '$flag')
    print(value if value else "")
    sys.exit(0)
else:
    print(f"Unknown operation: $operation", file=sys.stderr)
    sys.exit(1)
EOF
}

################################################################################
# Main Remediation Logic (Python-Based for Safety)
################################################################################

main() {
    log_info "Starting CIS 1.2.5 Remediation: kubelet-certificate-authority"
    log_info "Target manifest: $API_SERVER_MANIFEST"
    log_info "Using Python-based YAML modification (safe from sed delimiter conflicts)"
    
    # Check if manifest exists
    if [[ ! -f "$API_SERVER_MANIFEST" ]]; then
        log_error "API server manifest not found: $API_SERVER_MANIFEST"
        exit 1
    fi
    
    # Check if Python helper is available
    if [[ ! -f "$PYTHON_HELPER" ]]; then
        log_error "Python helper not found: $PYTHON_HELPER"
        log_error "Falling back to sed-based modification (may fail with complex paths)"
        exit 1
    fi
    
    # Auto-detect CA certificate
    CA_CERT_PATH=$(detect_ca_certificate) || {
        # Safe failover: CA not found - skip remediation gracefully
        log_warning "[WARN] CA Certificate not found. Skipping remediation to prevent cluster breakage."
        log_info "Manual action required: Please verify CA certificate location and set it manually"
        exit 0  # Exit with success code to avoid blocking automation
    }
    
    log_info "Using CA certificate: $CA_CERT_PATH"
    
    # Create backup using Python helper
    if ! backup_manifest; then
        exit 1
    fi
    
    # Check if flag already exists using Python helper
    log_info "Checking if --kubelet-certificate-authority is already set..."
    
    if call_python_modifier "check" "$API_SERVER_MANIFEST" "kube-apiserver" "--kubelet-certificate-authority" "" 2>/dev/null; then
        log_info "Flag already exists in manifest"
        
        # Check if it points to the correct path
        if call_python_modifier "check" "$API_SERVER_MANIFEST" "kube-apiserver" "--kubelet-certificate-authority" "$CA_CERT_PATH" 2>/dev/null; then
            log_success "Flag is already correctly configured to: $CA_CERT_PATH"
            exit 0
        else
            log_warning "Flag exists but points to wrong path. Updating..."
            
            # Remove old flag using Python helper
            if ! call_python_modifier "remove" "$API_SERVER_MANIFEST" "kube-apiserver" "--kubelet-certificate-authority" 2>/dev/null; then
                log_error "Failed to remove old kubelet-certificate-authority flag"
                log_error "Restoring from backup..."
                cp "$BACKUP_DIR/kube-apiserver.yaml.bak" "$API_SERVER_MANIFEST"
                exit 1
            fi
        fi
    fi
    
    log_info "Adding --kubelet-certificate-authority=$CA_CERT_PATH to manifest..."
    
    # Add the flag using Python helper (SAFE - no sed delimiter conflicts!)
    if ! call_python_modifier "add" "$API_SERVER_MANIFEST" "kube-apiserver" "--kubelet-certificate-authority" "$CA_CERT_PATH" 2>/dev/null; then
        log_error "Failed to add kubelet-certificate-authority flag"
        log_error "Restoring from backup..."
        cp "$BACKUP_DIR/kube-apiserver.yaml.bak" "$API_SERVER_MANIFEST"
        exit 1
    fi
    
    # Verification step - using Python helper (no sed/grep needed!)
    log_info "Verifying the change..."
    
    # Check if flag exists using Python helper
    if call_python_modifier "check" "$API_SERVER_MANIFEST" "kube-apiserver" "--kubelet-certificate-authority" "$CA_CERT_PATH" 2>/dev/null; then
        log_success "Verification passed: --kubelet-certificate-authority flag found in manifest"
        
        # Extract and display the actual value using Python helper
        ACTUAL_VALUE=$(call_python_modifier "get_value" "$API_SERVER_MANIFEST" "kube-apiserver" "--kubelet-certificate-authority" 2>/dev/null || echo "unknown")
        log_success "Flag value: $ACTUAL_VALUE"
        
        # Batch mode handling
        if [[ "$CIS_NO_RESTART" == "true" ]]; then
            log_warning "CIS_NO_RESTART is set to true: Manifest edited but NOT moved (no restart triggered)"
            log_info "The API server static pod will be restarted on next manifest change or system restart"
        else
            log_info "Static pod will auto-restart due to manifest modification"
            sleep 2
        fi
        
        log_success "CIS 1.2.5 Remediation completed successfully"
        exit 0
    else
        log_error "Verification failed: --kubelet-certificate-authority flag not found in manifest"
        log_error "Attempting to restore from backup..."
        
        if cp "$BACKUP_DIR/kube-apiserver.yaml.bak" "$API_SERVER_MANIFEST"; then
            log_success "Restored from backup"
        fi
        
        exit 1
    fi
}

# Execute main function
main "$@"
