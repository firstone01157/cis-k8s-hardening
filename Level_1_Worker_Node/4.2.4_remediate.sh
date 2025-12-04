#!/bin/bash
# CIS Benchmark: 4.2.4
# Title: Verify that if defined, readOnlyPort is set to 0 (Manual)
# Level: • Level 1 - Worker Node

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration
KUBELET_CONFIG="/var/lib/kubelet/config.yaml"
BACKUP_DIR="/var/backups/cis-remediation"
CONFIG_KEY="readOnlyPort"
DESIRED_VALUE="0"
TIMESTAMP_FILE="/tmp/kubelet_last_restart.timestamp"
RESTART_INTERVAL_SECONDS=60

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color

################################################################################
# LOGGING FUNCTIONS
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

################################################################################
# PREREQUISITE CHECKS
################################################################################

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

check_config_exists() {
    if [[ ! -f "$KUBELET_CONFIG" ]]; then
        log_error "Kubelet config not found at $KUBELET_CONFIG"
        exit 1
    fi
    log_pass "Kubelet config found: $KUBELET_CONFIG"
}

################################################################################
# BACKUP & VALIDATION
################################################################################

create_backup() {
    # Create backup directory if needed
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log_info "Creating backup directory: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR" || {
            log_warn "Could not create backup directory, continuing anyway"
            return 0
        }
    fi
    
    # Create timestamped backup
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/config.yaml.${timestamp}.bak"
    
    if cp "$KUBELET_CONFIG" "$backup_file"; then
        log_info "Backup created: $backup_file"
        return 0
    else
        log_warn "Could not create backup, continuing anyway"
        return 0
    fi
}

validate_yaml() {
    # Check if file is valid YAML using Python if available
    # Otherwise, just check basic structure
    
    if command -v python3 &>/dev/null; then
        if python3 -c "import yaml; yaml.safe_load(open('$KUBELET_CONFIG'))" 2>/dev/null; then
            log_pass "Config is valid YAML"
            return 0
        else
            log_error "Config is not valid YAML"
            return 1
        fi
    else
        # Fallback: just check if it looks like YAML (has colons)
        if grep -q ":" "$KUBELET_CONFIG"; then
            log_pass "Config looks like YAML"
            return 0
        else
            log_error "Config does not look like YAML"
            return 1
        fi
    fi
}

################################################################################
# REMEDIATION - MAIN LOGIC
################################################################################

remediate_readonly_port() {
    log_info "Remediating $CONFIG_KEY in $KUBELET_CONFIG..."
    
    # Check if key already exists in the file
    if grep -q "^${CONFIG_KEY}:" "$KUBELET_CONFIG"; then
        log_info "Found existing $CONFIG_KEY entry, updating value..."
        
        # Use sed to replace the existing line
        # Matches: readOnlyPort: <any_value>
        # Replaces with: readOnlyPort: 0
        if sed -i "s/^${CONFIG_KEY}:.*/${CONFIG_KEY}: ${DESIRED_VALUE}/" "$KUBELET_CONFIG"; then
            log_pass "Updated $CONFIG_KEY to $DESIRED_VALUE"
        else
            log_error "Failed to update $CONFIG_KEY with sed"
            return 1
        fi
    else
        log_warn "$CONFIG_KEY not found in config, appending..."
        
        # Append the key to the end of the file
        # Add proper indentation (root-level key = no indent)
        echo "${CONFIG_KEY}: ${DESIRED_VALUE}" >> "$KUBELET_CONFIG" || {
            log_error "Failed to append $CONFIG_KEY to config"
            return 1
        }
        log_pass "Appended $CONFIG_KEY: $DESIRED_VALUE to end of config"
    fi
    
    return 0
}

################################################################################
# VERIFICATION
################################################################################

verify_remediation() {
    log_info "Verifying remediation..."
    
    # Check if the line now contains the desired value
    if grep -q "^${CONFIG_KEY}: ${DESIRED_VALUE}" "$KUBELET_CONFIG"; then
        log_pass "$CONFIG_KEY is set to $DESIRED_VALUE"
        return 0
    else
        log_error "Verification failed: $CONFIG_KEY not set to $DESIRED_VALUE"
        return 1
    fi
}

################################################################################
# RESTART HANDLING WITH BATCH MODE SUPPORT
################################################################################

should_restart() {
    # Check CIS_NO_RESTART environment variable
    # If set to "true" (case-insensitive), skip restart
    
    local restart_mode="${CIS_NO_RESTART:-false}"
    
    if [[ "$restart_mode" == "true" ]]; then
        log_info "CIS_NO_RESTART is set to 'true' - skipping restart"
        log_warn "Kubelet will be restarted after all batch operations complete"
        return 1  # Don't restart
    fi
    
    return 0  # Do restart
}

can_restart_now() {
    # Check if we've restarted recently (within RESTART_INTERVAL_SECONDS)
    # This prevents systemd "Start Limit Burst" protection from triggering
    
    local current_time
    current_time=$(date +%s)
    
    if [[ -f "$TIMESTAMP_FILE" ]]; then
        local last_restart_time
        last_restart_time=$(cat "$TIMESTAMP_FILE" 2>/dev/null || echo "0")
        
        local time_diff=$((current_time - last_restart_time))
        
        if [[ $time_diff -lt $RESTART_INTERVAL_SECONDS ]]; then
            log_warn "Last restart was ${time_diff}s ago (need ${RESTART_INTERVAL_SECONDS}s interval)"
            log_warn "Skipping restart to avoid systemd burst limit"
            return 1  # Can't restart yet
        fi
    fi
    
    return 0  # Can restart
}

restart_kubelet() {
    # Only restart if:
    # 1. CIS_NO_RESTART is not "true"
    # 2. Enough time has passed since last restart
    
    if ! should_restart; then
        return 0  # Skip restart (batch mode)
    fi
    
    if ! can_restart_now; then
        log_warn "CONFIG UPDATED. Manual restart recommended when ready:"
        log_warn "  systemctl restart kubelet"
        return 0  # Don't fail, config is still updated
    fi
    
    log_info "Restarting kubelet..."
    
    # Reload systemd daemon-reload first
    if ! systemctl daemon-reload; then
        log_error "Failed to run systemctl daemon-reload"
        return 1
    fi
    
    # Restart kubelet
    if ! systemctl restart kubelet; then
        log_error "Failed to restart kubelet"
        return 1
    fi
    
    # Record the restart time
    echo "$(date +%s)" > "$TIMESTAMP_FILE" 2>/dev/null || true
    
    # Wait for kubelet to become active (up to 15 seconds)
    log_info "Waiting for kubelet to become active..."
    
    local max_attempts=15
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        ((attempt++))
        
        if systemctl is-active --quiet kubelet; then
            log_pass "kubelet is now active"
            return 0
        fi
        
        sleep 1
        
        if [[ $attempt -lt $max_attempts ]]; then
            log_info "Waiting... ($attempt/$max_attempts)"
        fi
    done
    
    # Final status check
    if systemctl is-active --quiet kubelet; then
        log_pass "kubelet restart successful"
        return 0
    else
        log_error "kubelet did not become active after $max_attempts seconds"
        return 1
    fi
}

################################################################################
# MAIN EXECUTION
################################################################################

main() {
    log_info "========================================"
    log_info "CIS 4.2.4: Set readOnlyPort to 0"
    log_info "========================================"
    log_info ""
    
    # Step 1: Prerequisites
    log_info "STEP 1: Checking prerequisites..."
    check_root
    check_config_exists
    log_info ""
    
    # Step 2: Backup
    log_info "STEP 2: Creating backup..."
    create_backup
    log_info ""
    
    # Step 3: Remediate
    log_info "STEP 3: Remediating readOnlyPort..."
    if ! remediate_readonly_port; then
        log_error "Remediation failed"
        return 1
    fi
    log_info ""
    
    # Step 4: Validate YAML
    log_info "STEP 4: Validating YAML structure..."
    if ! validate_yaml; then
        log_error "YAML validation failed - backup available for rollback"
        return 1
    fi
    log_info ""
    
    # Step 5: Verify remediation
    log_info "STEP 5: Verifying remediation..."
    if ! verify_remediation; then
        log_error "Verification failed"
        return 1
    fi
    log_info ""
    
    # Step 6: Restart kubelet (respecting batch mode)
    log_info "STEP 6: Handling kubelet restart..."
    if ! restart_kubelet; then
        log_error "Restart handling failed"
        return 1
    fi
    log_info ""
    
    log_pass "========================================"
    log_pass "CIS 4.2.4 remediation complete!"
    log_pass "========================================"
    
    return 0
}

# Run main function and capture exit code
main
exit_code=$?

exit $exit_code
