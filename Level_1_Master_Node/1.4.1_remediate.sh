#!/bin/bash
################################################################################
# CIS Kubernetes Benchmark 1.4.1 Remediation
# Ensure that the --profiling argument is set to false (Scheduler)
# 
# Description:
#   The Scheduler should have profiling disabled to prevent exposure of
#   sensitive scheduling and performance information.
#
# Impact: Low - Manifest modification, static pod auto-restart
# Kubernetes Version: 1.30+
# 
# Author: DevSecOps Team
# Date: 2025-12-08
################################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
ENDC='\033[0m'

# Configuration
MANIFEST_DIR="/etc/kubernetes/manifests"
SCHEDULER_MANIFEST="$MANIFEST_DIR/kube-scheduler.yaml"
LOG_FILE="/var/log/cis-remediation.log"
BACKUP_DIR="/var/backups/kubernetes/$(date +%Y%m%d_%H%M%S)_cis"

# Batch mode flag
CIS_NO_RESTART="${CIS_NO_RESTART:-false}"

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
# Backup Function
################################################################################

backup_manifest() {
    mkdir -p "$BACKUP_DIR"
    if cp "$SCHEDULER_MANIFEST" "$BACKUP_DIR/kube-scheduler.yaml.bak"; then
        log_success "Backup created: $BACKUP_DIR/kube-scheduler.yaml.bak"
        return 0
    else
        log_error "Failed to create backup"
        return 1
    fi
}

################################################################################
# Main Remediation Logic
################################################################################

main() {
    log_info "Starting CIS 1.4.1 Remediation: Scheduler profiling disabled"
    log_info "Target manifest: $SCHEDULER_MANIFEST"
    
    # Check if manifest exists
    if [[ ! -f "$SCHEDULER_MANIFEST" ]]; then
        log_error "Scheduler manifest not found: $SCHEDULER_MANIFEST"
        exit 1
    fi
    
    # Create backup
    if ! backup_manifest; then
        exit 1
    fi
    
    # Check if flag already exists
    log_info "Checking if --profiling flag exists..."
    
    if grep -q "^\s*-\s*--profiling" "$SCHEDULER_MANIFEST"; then
        log_info "Flag already exists"
        
        # Check if it's set to false
        if grep -q "^\s*-\s*--profiling=false" "$SCHEDULER_MANIFEST"; then
            log_success "Flag is already correctly set to: false"
            exit 0
        else
            log_warning "Flag exists but not set to false. Updating..."
            
            # Remove old flag
            sed -i "/--profiling=/d" "$SCHEDULER_MANIFEST"
        fi
    fi
    
    log_info "Adding --profiling=false to Scheduler manifest..."
    
    # Add the flag after the kube-scheduler line
    sed -i "/- kube-scheduler/a\        - --profiling=false" "$SCHEDULER_MANIFEST"
    
    # Verification step
    log_info "Verifying the change..."
    
    if grep -q "^\s*-\s*--profiling=false" "$SCHEDULER_MANIFEST"; then
        log_success "Verification passed: --profiling=false flag found in manifest"
        
        # Display the verified line
        VERIFIED_LINE=$(grep "^\s*-\s*--profiling" "$SCHEDULER_MANIFEST")
        log_success "Verified configuration: $VERIFIED_LINE"
        
        # Batch mode handling
        if [[ "$CIS_NO_RESTART" == "true" ]]; then
            log_warning "CIS_NO_RESTART is set: Manifest edited but NOT moved"
        else
            log_info "Static pod will auto-restart due to manifest modification"
            sleep 2
        fi
        
        log_success "CIS 1.4.1 Remediation completed successfully"
        exit 0
    else
        log_error "Verification failed: --profiling=false not found in manifest"
        
        if cp "$BACKUP_DIR/kube-scheduler.yaml.bak" "$SCHEDULER_MANIFEST"; then
            log_success "Restored from backup"
        fi
        
        exit 1
    fi
}

# Execute main function
main "$@"
