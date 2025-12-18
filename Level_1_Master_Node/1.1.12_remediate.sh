#!/bin/bash
################################################################################
# CIS Kubernetes Benchmark 1.1.12 Remediation
# Ensure that the etcd data directory ownership is set to etcd:etcd
# 
# Description:
#   The etcd database should be owned by the etcd user and group (etcd:etcd).
#   This ensures that only the etcd process can read/write to the database.
#
# Auto-Detection: Automatically detects etcd data directory from process args
# Auto-Create: Automatically creates etcd user/group if missing
# Safe Failover: Gracefully handles missing components
# 
# Impact: Low - Ownership change only, no configuration modification
# 
# Author: DevSecOps Team
# Date: 2025-12-08
################################################################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
ENDC='\033[0m'

# Configuration
ETCD_DATA_DIR="${ETCD_DATA_DIR:-/var/lib/etcd}"

# Sanitize ETCD_DATA_DIR to remove any leading/trailing quotes
ETCD_DATA_DIR=$(echo "$ETCD_DATA_DIR" | sed 's/^["\x27]//;s/["\x27]$//')

ETCD_USER="etcd"
ETCD_GROUP="etcd"
LOG_FILE="/var/log/cis-remediation.log"

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
# Auto-Detect Etcd Data Directory
################################################################################

detect_etcd_directory() {
    # First try environment variable override
    if [[ -n "${ETCD_DATA_DIR:-}" && -d "$ETCD_DATA_DIR" ]]; then
        log_info "Using ETCD_DATA_DIR: $ETCD_DATA_DIR"
        return 0
    fi
    
    # Try to detect from etcd process arguments
    if command -v ps &> /dev/null; then
        local proc_dir=$(ps aux 2>/dev/null | grep -i "etcd" | grep -v grep | head -1 | grep -oP '(\--data-dir=\K[^ ]+|data-dir=[^ ]+)' || echo "")
        
        if [[ -n "$proc_dir" ]]; then
            # Extract the path from --data-dir=VALUE format
            local extracted_path="${proc_dir#--data-dir=}"
            extracted_path="${extracted_path#data-dir=}"
            
            if [[ -d "$extracted_path" ]]; then
                ETCD_DATA_DIR="$extracted_path"
                log_info "Auto-detected ETCD_DATA_DIR from process args: $ETCD_DATA_DIR"
                return 0
            fi
        fi
    fi
    
    # Check common etcd locations
    local common_paths=("/var/lib/etcd" "/etcd/data" "/var/etcd")
    for path in "${common_paths[@]}"; do
        if [[ -d "$path" ]]; then
            ETCD_DATA_DIR="$path"
            log_info "Found ETCD_DATA_DIR at common location: $ETCD_DATA_DIR"
            return 0
        fi
    done
    
    # Default to /var/lib/etcd (already set above)
    log_info "Using default ETCD_DATA_DIR: $ETCD_DATA_DIR"
    return 0
}

################################################################################
# Check and Auto-Create Etcd User/Group
################################################################################

ensure_etcd_user_group() {
    log_info "Checking if user '$ETCD_USER' and group '$ETCD_GROUP' exist..."
    
    # Check if group exists
    if ! getent group "$ETCD_GROUP" > /dev/null 2>&1; then
        log_warning "Group '$ETCD_GROUP' not found. Creating it..."
        
        if groupadd -r "$ETCD_GROUP" 2>/dev/null; then
            log_success "[INFO] Group '$ETCD_GROUP' created."
        else
            log_error "Failed to create group '$ETCD_GROUP'"
            return 1
        fi
    else
        log_info "Group '$ETCD_GROUP' already exists"
    fi
    
    # Check if user exists
    if ! getent passwd "$ETCD_USER" > /dev/null 2>&1; then
        log_warning "User '$ETCD_USER' not found. Creating it..."
        
        if useradd -r -s /bin/false -g "$ETCD_GROUP" "$ETCD_USER" 2>/dev/null; then
            log_success "[INFO] User '$ETCD_USER' created."
        else
            log_error "Failed to create user '$ETCD_USER'"
            return 1
        fi
    else
        log_info "User '$ETCD_USER' already exists"
    fi
    
    return 0
}

################################################################################
# Main Remediation Logic
################################################################################

main() {
    log_info "Starting CIS 1.1.12 Remediation: etcd data directory ownership"
    
    # Auto-detect etcd data directory
    detect_etcd_directory
    
    log_info "Target directory: $ETCD_DATA_DIR"
    
    # Check if etcd data directory exists
    if [[ ! -d "$ETCD_DATA_DIR" ]]; then
        log_error "etcd data directory not found: $ETCD_DATA_DIR"
        exit 1
    fi
    
    # Ensure etcd user and group exist (auto-create if needed)
    if ! ensure_etcd_user_group; then
        log_error "Failed to ensure etcd user/group existence"
        exit 1
    fi
    
    log_info "Checking current ownership of $ETCD_DATA_DIR..."
    
    # Get current ownership
    CURRENT_OWNER=$(stat -c "%U:%G" "$ETCD_DATA_DIR" 2>/dev/null || echo "unknown:unknown")
    log_info "Current ownership: $CURRENT_OWNER"
    
    # Check if ownership is already correct
    if [[ "$CURRENT_OWNER" == "$ETCD_USER:$ETCD_GROUP" ]]; then
        log_success "etcd data directory ownership is already correct: $CURRENT_OWNER"
        exit 0
    fi
    
    log_warning "etcd data directory ownership is incorrect: $CURRENT_OWNER (expected: $ETCD_USER:$ETCD_GROUP)"
    
    # Change ownership recursively using chown
    log_info "Changing ownership of $ETCD_DATA_DIR to $ETCD_USER:$ETCD_GROUP recursively..."
    
    if chown -R "$ETCD_USER:$ETCD_GROUP" "$ETCD_DATA_DIR" 2>/dev/null; then
        log_success "Ownership change command executed successfully"
    else
        log_error "Failed to change ownership of $ETCD_DATA_DIR"
        exit 1
    fi
    
    # Verify the change
    log_info "Verifying ownership change..."
    VERIFIED_OWNER=$(stat -c "%U:%G" "$ETCD_DATA_DIR" 2>/dev/null || echo "unknown:unknown")
    
    if [[ "$VERIFIED_OWNER" == "$ETCD_USER:$ETCD_GROUP" ]]; then
        log_success "Verification successful: $ETCD_DATA_DIR ownership is now $VERIFIED_OWNER"
        
        # Verify a sample of files within the directory (first 10 files)
        log_info "Verifying sample files within $ETCD_DATA_DIR..."
        SAMPLE_COUNT=0
        CORRECT_COUNT=0
        
        while IFS= read -r file; do
            SAMPLE_COUNT=$((SAMPLE_COUNT + 1))
            FILE_OWNER=$(stat -c "%U:%G" "$file" 2>/dev/null || echo "unknown:unknown")
            if [[ "$FILE_OWNER" == "$ETCD_USER:$ETCD_GROUP" ]]; then
                CORRECT_COUNT=$((CORRECT_COUNT + 1))
            fi
            [[ $SAMPLE_COUNT -ge 10 ]] && break
        done < <(find "$ETCD_DATA_DIR" -type f 2>/dev/null | head -10)
        
        if [[ $SAMPLE_COUNT -gt 0 && $CORRECT_COUNT -eq $SAMPLE_COUNT ]]; then
            log_success "Sample files verified: $CORRECT_COUNT/$SAMPLE_COUNT files have correct ownership"
        else
            log_warning "Some sample files may not have correct ownership: $CORRECT_COUNT/$SAMPLE_COUNT"
        fi
        
        log_success "CIS 1.1.12 Remediation completed successfully"
        exit 0
    else
        log_error "Verification failed: $ETCD_DATA_DIR ownership is still $VERIFIED_OWNER (expected: $ETCD_USER:$ETCD_GROUP)"
        exit 1
    fi
}

# Execute main function
main "$@"