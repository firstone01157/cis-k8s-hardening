#!/bin/bash

################################################################################
# CIS Kubernetes Benchmark v1.34 - Master Node Remediation Script
# 
# Purpose: Safely apply security hardening fixes to Kubernetes static pod
#          manifests on the master node.
#
# Fixes Applied:
#   1.2.5:  Add kubelet certificate authority
#   1.2.7:  Add Node,RBAC to authorization-mode
#   1.2.30: Disable token expiration extension
#   1.3.6:  Enable kubelet server certificate rotation
#   1.4.1:  Disable kubelet profiling
#
# Safety Features:
#   - Creates timestamped backups before modifying
#   - Uses Python manifest hardener (no sed fragility)
#   - Smart deduplication (no duplicate flags)
#   - Intelligent merging (no data loss on list flags)
#   - Validates changes before applying
#
# Exit Codes:
#   0 = Success
#   1 = Error (check logs)
#
################################################################################

set -euo pipefail

# Configuration
SCRIPT_NAME="$(basename "$0")"
LOG_FILE="/var/log/cis-remediate-master-node.log"
MANIFEST_DIR="/etc/kubernetes/manifests"
PYTHON_HARDENER="/usr/local/bin/harden_manifests.py"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Logging Functions
################################################################################

log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $*" | tee -a "$LOG_FILE"
}

log_pass() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [PASS] $*${NC}" | tee -a "$LOG_FILE"
}

log_fail() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] [FAIL] $*${NC}" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [WARN] $*${NC}" | tee -a "$LOG_FILE"
}

log_section() {
    echo "" | tee -a "$LOG_FILE"
    echo "========================================================================" | tee -a "$LOG_FILE"
    echo "  $*" | tee -a "$LOG_FILE"
    echo "========================================================================" | tee -a "$LOG_FILE"
}

################################################################################
# Validation Functions
################################################################################

check_prerequisites() {
    log_section "Checking Prerequisites"
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_fail "This script must be run as root"
        exit 1
    fi
    log_pass "Running as root"
    
    # Check if manifest directory exists
    if [[ ! -d "$MANIFEST_DIR" ]]; then
        log_fail "Manifest directory not found: $MANIFEST_DIR"
        exit 1
    fi
    log_pass "Manifest directory found: $MANIFEST_DIR"
    
    # Check if kube-apiserver manifest exists
    if [[ ! -f "$MANIFEST_DIR/kube-apiserver.yaml" ]]; then
        log_fail "kube-apiserver.yaml not found in $MANIFEST_DIR"
        exit 1
    fi
    log_pass "kube-apiserver.yaml found"
    
    # Check if Python hardener exists
    if [[ ! -f "$PYTHON_HARDENER" ]] && [[ ! -f "./harden_manifests.py" ]]; then
        log_fail "Python manifest hardener not found. Expected: $PYTHON_HARDENER or ./harden_manifests.py"
        exit 1
    fi
    
    if [[ ! -f "$PYTHON_HARDENER" ]] && [[ -f "./harden_manifests.py" ]]; then
        PYTHON_HARDENER="./harden_manifests.py"
    fi
    log_pass "Python hardener found: $PYTHON_HARDENER"
    
    # Check if Python 3 is available
    if ! command -v python3 &> /dev/null; then
        log_fail "Python 3 not found"
        exit 1
    fi
    log_pass "Python 3 available"
}

create_backup() {
    local manifest_file="$1"
    local backup_dir="${manifest_file%/*}/backups"
    local backup_file="${backup_dir}/$(basename "$manifest_file")_${TIMESTAMP}.bak"
    
    # Create backup directory
    mkdir -p "$backup_dir"
    
    # Create backup
    cp "$manifest_file" "$backup_file"
    
    log_pass "Backup created: $backup_file"
    echo "$backup_file"
}

################################################################################
# Remediation Functions
################################################################################

remediate_flag() {
    local manifest_file="$1"
    local flag_name="$2"
    local flag_value="$3"
    local fix_id="$4"
    
    log_info "[CIS $fix_id] Applying: $flag_name=$flag_value to $(basename "$manifest_file")"
    
    # Create backup
    create_backup "$manifest_file"
    
    # Apply the fix using Python hardener
    if python3 "$PYTHON_HARDENER" \
        --manifest "$manifest_file" \
        --flag "$flag_name" \
        --value "$flag_value" \
        --verbose >> "$LOG_FILE" 2>&1; then
        log_pass "[CIS $fix_id] Successfully applied $flag_name"
        return 0
    else
        log_fail "[CIS $fix_id] Failed to apply $flag_name"
        return 1
    fi
}

remediate_kube_apiserver() {
    log_section "Remediating kube-apiserver.yaml"
    
    local manifest="$MANIFEST_DIR/kube-apiserver.yaml"
    local failed=0
    
    # Fix 1.2.5: kubelet-certificate-authority
    if ! remediate_flag "$manifest" "kubelet-certificate-authority" \
        "/etc/kubernetes/pki/ca.crt" "1.2.5"; then
        ((failed++))
    fi
    
    # Fix 1.2.7: authorization-mode
    log_info "[CIS 1.2.7] Ensuring authorization-mode includes Node,RBAC"
    create_backup "$manifest"
    
    if python3 << 'PYEOF'
import sys
sys.path.insert(0, '/home/first/Project/cis-k8s-hardening')
from harden_manifests import ManifestHardener

try:
    h = ManifestHardener('/etc/kubernetes/manifests/kube-apiserver.yaml')
    h.merge_plugins('authorization-mode', ['Node', 'RBAC'], verbose=True)
    result = h.apply()
    if result['changed']:
        print('[PASS] Authorization mode updated')
    else:
        print('[PASS] Authorization mode already correct')
except Exception as e:
    print(f'[FAIL] {e}')
    sys.exit(1)
PYEOF
    then
        log_pass "[CIS 1.2.7] Successfully applied authorization-mode"
    else
        log_fail "[CIS 1.2.7] Failed to apply authorization-mode"
        ((failed++))
    fi
    
    # Fix 1.2.30: service-account-extend-token-expiration
    if ! remediate_flag "$manifest" "service-account-extend-token-expiration" \
        "false" "1.2.30"; then
        ((failed++))
    fi
    
    return $failed
}

remediate_kube_controller_manager() {
    log_section "Remediating kube-controller-manager.yaml"
    
    local manifest="$MANIFEST_DIR/kube-controller-manager.yaml"
    local failed=0
    
    # Fix 1.3.6: feature-gates
    log_info "[CIS 1.3.6] Setting feature-gates for kubelet server certificate rotation"
    create_backup "$manifest"
    
    if python3 << 'PYEOF'
import sys
sys.path.insert(0, '/home/first/Project/cis-k8s-hardening')
from harden_manifests import ManifestHardener

try:
    h = ManifestHardener('/etc/kubernetes/manifests/kube-controller-manager.yaml')
    h.merge_plugins('feature-gates', ['RotateKubeletServerCertificate=true'], verbose=True)
    result = h.apply()
    if result['changed']:
        print('[PASS] Feature gates updated')
    else:
        print('[PASS] Feature gates already correct')
except Exception as e:
    print(f'[FAIL] {e}')
    sys.exit(1)
PYEOF
    then
        log_pass "[CIS 1.3.6] Successfully applied feature-gates"
    else
        log_fail "[CIS 1.3.6] Failed to apply feature-gates"
        ((failed++))
    fi
    
    return $failed
}

remediate_kube_scheduler() {
    log_section "Remediating kube-scheduler.yaml"
    
    local manifest="$MANIFEST_DIR/kube-scheduler.yaml"
    local failed=0
    
    # Fix 1.4.1: profiling
    if ! remediate_flag "$manifest" "profiling" "false" "1.4.1"; then
        ((failed++))
    fi
    
    return $failed
}

################################################################################
# Validation Functions
################################################################################

validate_changes() {
    log_section "Validating Changes"
    
    # Check if manifests are still valid YAML
    for manifest in kube-apiserver kube-controller-manager kube-scheduler; do
        if ! python3 -c "import yaml; yaml.safe_load(open('$MANIFEST_DIR/${manifest}.yaml'))" 2>/dev/null; then
            log_fail "Invalid YAML syntax in ${manifest}.yaml"
            return 1
        fi
        log_pass "YAML syntax valid: ${manifest}.yaml"
    done
    
    return 0
}

restart_kubelet() {
    log_section "Restarting Kubelet"
    
    if ! command -v systemctl &> /dev/null; then
        log_warn "systemctl not found - cannot restart kubelet"
        return 1
    fi
    
    log_info "Restarting kubelet to apply new configurations..."
    
    if systemctl restart kubelet; then
        log_pass "Kubelet restarted successfully"
        sleep 5  # Give kubelet time to restart
        return 0
    else
        log_fail "Failed to restart kubelet"
        return 1
    fi
}

################################################################################
# Main Execution
################################################################################

main() {
    log_section "CIS Kubernetes Benchmark - Master Node Remediation"
    log_info "Timestamp: $TIMESTAMP"
    log_info "Log file: $LOG_FILE"
    
    # Check prerequisites
    if ! check_prerequisites; then
        log_fail "Prerequisites check failed"
        exit 1
    fi
    
    local total_failed=0
    
    # Apply remediations
    if ! remediate_kube_apiserver; then
        ((total_failed++))
    fi
    
    if ! remediate_kube_controller_manager; then
        ((total_failed++))
    fi
    
    if ! remediate_kube_scheduler; then
        ((total_failed++))
    fi
    
    # Validate changes
    if ! validate_changes; then
        log_fail "Validation failed - manifest integrity compromised"
        exit 1
    fi
    
    # Restart kubelet
    if ! restart_kubelet; then
        log_warn "Kubelet restart encountered issues"
    fi
    
    # Final summary
    log_section "Remediation Summary"
    if [[ $total_failed -eq 0 ]]; then
        log_pass "All remediations completed successfully!"
        exit 0
    else
        log_fail "Remediations completed with $total_failed error(s)"
        log_info "Review $LOG_FILE for details"
        exit 1
    fi
}

# Run main function
main "$@"
