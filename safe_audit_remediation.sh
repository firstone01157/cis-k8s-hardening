#!/bin/bash
#
# Safe Audit Logging Remediation for CIS 1.2.15-1.2.19
# Fixes: --audit-log-path, --audit-policy-file, --audit-log-maxage, 
#        --audit-log-maxbackup, --audit-log-maxsize
#
# CRITICAL FEATURES:
# - Creates /var/log/kubernetes/audit directory with proper permissions
# - Creates a valid minimal audit-policy.yaml file
# - Atomically updates kube-apiserver.yaml with proper YAML indentation
# - Adds volumeMounts and volumes to ensure Pod can access resources
# - Validates YAML indentation before saving
# - Creates timestamped backups before modifications
#

set -o pipefail

##############################################################################
# CONFIGURATION
##############################################################################

MANIFEST_DIR="/etc/kubernetes/manifests"
APISERVER_MANIFEST="${MANIFEST_DIR}/kube-apiserver.yaml"
AUDIT_DIR="/var/log/kubernetes/audit"
AUDIT_LOG_PATH="${AUDIT_DIR}/audit.log"
AUDIT_POLICY_PATH="${AUDIT_DIR}/audit-policy.yaml"
BACKUP_DIR="/var/backups/kubernetes"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TEMP_MANIFEST="/tmp/kube-apiserver.yaml.tmp.$$"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
SUCCESSES=0
WARNINGS=0
ERRORS=0

##############################################################################
# LOGGING FUNCTIONS
##############################################################################

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    ((SUCCESSES++))
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
    ((WARNINGS++))
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    ((ERRORS++))
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_header() {
    echo ""
    echo "================================================================================"
    echo "$1"
    echo "================================================================================"
}

##############################################################################
# PHASE 1: PREREQUISITES CHECK
##############################################################################

check_prerequisites() {
    print_header "PHASE 1: Checking Prerequisites"
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        return 1
    fi
    log_success "Running as root"
    
    # Check if manifest directory exists
    if [[ ! -d "$MANIFEST_DIR" ]]; then
        log_error "Manifest directory not found: $MANIFEST_DIR"
        return 1
    fi
    log_success "Manifest directory exists: $MANIFEST_DIR"
    
    # Check if kube-apiserver manifest exists
    if [[ ! -f "$APISERVER_MANIFEST" ]]; then
        log_error "Manifest not found: $APISERVER_MANIFEST"
        return 1
    fi
    log_success "Manifest found: $APISERVER_MANIFEST"
    
    # Check if kube-apiserver process exists
    if pgrep -f "kube-apiserver" > /dev/null; then
        log_success "kube-apiserver process detected"
    else
        log_warning "kube-apiserver process not detected - verify you're on master node"
    fi
    
    return 0
}

##############################################################################
# PHASE 2: BACKUP SETUP
##############################################################################

create_backup_dir() {
    print_header "PHASE 2: Creating Backup Directory"
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        if mkdir -p "$BACKUP_DIR" && chmod 750 "$BACKUP_DIR"; then
            log_success "Created backup directory: $BACKUP_DIR"
        else
            log_error "Failed to create backup directory: $BACKUP_DIR"
            return 1
        fi
    else
        log_success "Backup directory exists: $BACKUP_DIR"
    fi
    
    return 0
}

##############################################################################
# PHASE 3: BACKUP MANIFEST
##############################################################################

backup_manifest() {
    print_header "PHASE 3: Backing Up Current Manifest"
    
    local backup_file="${BACKUP_DIR}/kube-apiserver.yaml.backup_${TIMESTAMP}"
    
    if cp "$APISERVER_MANIFEST" "$backup_file"; then
        chmod 640 "$backup_file"
        log_success "Backup created: $backup_file"
    else
        log_error "Failed to backup manifest"
        return 1
    fi
    
    return 0
}

##############################################################################
# PHASE 4: CREATE AUDIT DIRECTORY
##############################################################################

create_audit_directory() {
    print_header "PHASE 4: Creating Audit Directory"
    
    if [[ -d "$AUDIT_DIR" ]]; then
        # Verify permissions
        local mode=$(stat -c "%a" "$AUDIT_DIR" 2>/dev/null || echo "unknown")
        if [[ "$mode" != "700" ]]; then
            log_warning "Audit dir exists with permissions $mode, resetting to 700"
            chmod 700 "$AUDIT_DIR"
        fi
        log_success "Audit directory exists: $AUDIT_DIR"
    else
        if mkdir -p "$AUDIT_DIR" && chmod 700 "$AUDIT_DIR"; then
            log_success "Created audit directory: $AUDIT_DIR"
        else
            log_error "Failed to create audit directory: $AUDIT_DIR"
            return 1
        fi
    fi
    
    return 0
}

##############################################################################
# PHASE 5: CREATE AUDIT POLICY FILE
##############################################################################

create_audit_policy() {
    print_header "PHASE 5: Creating Audit Policy File"
    
    # If audit policy already exists, back it up
    if [[ -f "$AUDIT_POLICY_PATH" ]]; then
        local backup_policy="${BACKUP_DIR}/audit-policy.yaml.backup_${TIMESTAMP}"
        if cp "$AUDIT_POLICY_PATH" "$backup_policy"; then
            log_warning "Audit policy already exists, backed up to $backup_policy"
        fi
    fi
    
    # Create the audit policy
    cat > "$AUDIT_POLICY_PATH" << 'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
# Log all requests at the Metadata level.
rules:
  - level: Metadata
    omitStages:
      - RequestReceived
  # Log pod exec at RequestResponse so we can see the request body
  - level: RequestResponse
    verbs: ["create"]
    resources:
      - group: ""
        resources: ["pods/exec", "pods/attach"]
    omitStages:
      - RequestReceived
  # Omit events, audit events themselves, and health checks
  - level: None
    resources:
      - group: ""
        resources: ["events"]
  - level: None
    resources:
      - group: "authentication.k8s.io"
        resources: ["tokenreviews"]
  - level: None
    nonResourceURLs:
      - /healthz*
      - /logs
      - /logs/*
EOF
    
    if [[ -f "$AUDIT_POLICY_PATH" ]]; then
        chmod 644 "$AUDIT_POLICY_PATH"
        log_success "Created audit policy: $AUDIT_POLICY_PATH"
        return 0
    else
        log_error "Failed to create audit policy: $AUDIT_POLICY_PATH"
        return 1
    fi
}

##############################################################################
# PHASE 6: VALIDATE YAML INDENTATION
##############################################################################

validate_yaml_indentation() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        log_error "File not found for validation: $file"
        return 1
    fi
    
    # Check for tabs (YAML doesn't allow tabs)
    if grep -q $'\t' "$file"; then
        log_error "YAML file contains tabs - YAML requires spaces only"
        return 1
    fi
    
    # Try to validate with python yaml if available
    if command -v python3 &> /dev/null; then
        python3 << PYSCRIPT 2>/dev/null
import sys
import yaml
try:
    with open('$file', 'r') as f:
        yaml.safe_load(f)
    sys.exit(0)
except Exception as e:
    print(f"YAML Error: {e}")
    sys.exit(1)
PYSCRIPT
        return $?
    fi
    
    # If python not available, do basic syntax checks
    log_warning "Python YAML validator not available, performing basic checks"
    
    # Check for unmatched colons or brackets
    local yaml_errors=0
    
    # Simple check: each indentation level should be consistent
    awk '
    BEGIN { prev_indent = -1; errors = 0 }
    {
        # Get leading spaces
        match($0, /^[ ]*/)
        indent = RLENGTH - 1
        
        # Skip empty lines
        if ($0 ~ /^[ ]*$/) next
        
        # Check if indent is multiple of 2
        if (indent % 2 != 0) {
            print "Line " NR ": Invalid indentation (not multiple of 2): indent=" indent
            errors++
        }
    }
    END { exit errors }
    ' "$file"
    
    yaml_errors=$?
    
    if [[ $yaml_errors -eq 0 ]]; then
        log_success "YAML indentation validation passed"
        return 0
    else
        log_error "YAML indentation validation failed (found $yaml_errors errors)"
        return 1
    fi
}

##############################################################################
# PHASE 7: LOAD AND PREPARE MANIFEST
##############################################################################

load_manifest() {
    if [[ ! -f "$APISERVER_MANIFEST" ]]; then
        log_error "Cannot load manifest: $APISERVER_MANIFEST"
        return 1
    fi
    
    cat "$APISERVER_MANIFEST"
    return 0
}

##############################################################################
# PHASE 8: ADD AUDIT FLAGS TO MANIFEST
##############################################################################

add_audit_flags() {
    local manifest_content="$1"
    local output="$2"
    
    print_header "PHASE 8: Adding Audit Logging Flags to kube-apiserver"
    
    # Array of flags to add
    declare -a flags=(
        "--audit-log-path=${AUDIT_LOG_PATH}"
        "--audit-policy-file=${AUDIT_POLICY_PATH}"
        "--audit-log-maxage=30"
        "--audit-log-maxbackup=10"
        "--audit-log-maxsize=100"
    )
    
    echo "$manifest_content" > "$output"
    
    # Check each flag and add if missing
    for flag in "${flags[@]}"; do
        local flag_name="${flag%%=*}"  # Extract flag name before =
        
        if grep -q "$flag_name" "$output"; then
            log_success "Flag $flag_name already present"
        else
            # Find the line with "- kube-apiserver" and add flag after it
            local line_num=$(grep -n "- kube-apiserver" "$output" | head -1 | cut -d: -f1)
            
            if [[ -n "$line_num" ]]; then
                # Get the indentation of the next line (should be the first existing flag)
                local next_line=$((line_num + 1))
                local indent=$(sed -n "${next_line}p" "$output" | sed 's/[^ ].*//' | wc -c)
                indent=$((indent - 1))  # Subtract 1 for the extra space
                
                # Create the indent string
                local indent_str=$(printf '%*s' "$indent" | tr ' ' ' ')
                
                # Find the last flag line
                local last_flag_line=$line_num
                local search_line=$((line_num + 1))
                
                while [[ $search_line -lt $(wc -l < "$output") ]]; do
                    local line_content=$(sed -n "${search_line}p" "$output")
                    if [[ "$line_content" =~ ^[[:space:]]*- ]]; then
                        last_flag_line=$search_line
                        search_line=$((search_line + 1))
                    else
                        break
                    fi
                done
                
                # Insert the flag after the last flag line
                sed -i "${last_flag_line}a\\${indent_str}- ${flag}" "$output"
                log_success "Added flag: $flag_name"
            else
                log_error "Could not find - kube-apiserver line"
                return 1
            fi
        fi
    done
    
    return 0
}

##############################################################################
# PHASE 9: ADD VOLUME MOUNTS TO MANIFEST
##############################################################################

add_volume_mounts() {
    local manifest_file="$1"
    
    print_header "PHASE 9: Adding volumeMounts for Audit"
    
    # Check if volumeMounts section exists
    if grep -q "volumeMounts:" "$manifest_file"; then
        log_success "volumeMounts section already exists"
        
        # Check if our mounts are already there
        if grep -q "name: audit-log" "$manifest_file"; then
            log_success "audit-log volumeMount already exists"
        else
            # Need to add to existing volumeMounts section
            # Find the volumeMounts line and get its indentation
            local vm_line=$(grep -n "volumeMounts:" "$manifest_file" | head -1 | cut -d: -f1)
            
            if [[ -n "$vm_line" ]]; then
                local indent=$(sed -n "${vm_line}p" "$manifest_file" | sed 's/[^ ].*//' | wc -c)
                indent=$((indent + 1))  # One more level of indentation
                
                local indent_str=$(printf '%*s' "$indent" | tr ' ' ' ')
                local next_line=$((vm_line + 1))
                
                # Insert the audit mounts
                sed -i "${next_line}i\\${indent_str}- name: audit-log\n${indent_str}  mountPath: ${AUDIT_DIR}\n${indent_str}  readOnly: false\n${indent_str}- name: audit-policy\n${indent_str}  mountPath: ${AUDIT_POLICY_PATH}\n${indent_str}  readOnly: true\n${indent_str}  subPath: audit-policy.yaml" "$manifest_file"
                
                log_success "Added audit volumeMounts"
            fi
        fi
    else
        # Need to add volumeMounts section
        # Find a good place to insert (after image line typically)
        local image_line=$(grep -n "image:" "$manifest_file" | head -1 | cut -d: -f1)
        
        if [[ -n "$image_line" ]]; then
            local indent=$(sed -n "$((image_line))p" "$manifest_file" | sed 's/[^ ].*//' | wc -c)
            indent=$((indent - 1))
            
            local indent_str=$(printf '%*s' "$indent" | tr ' ' ' ')
            
            local vm_content="${indent_str}volumeMounts:\n${indent_str}  - name: audit-log\n${indent_str}    mountPath: ${AUDIT_DIR}\n${indent_str}    readOnly: false\n${indent_str}  - name: audit-policy\n${indent_str}    mountPath: ${AUDIT_POLICY_PATH}\n${indent_str}    readOnly: true\n${indent_str}    subPath: audit-policy.yaml"
            
            sed -i "${image_line}a\\${vm_content}" "$manifest_file"
            log_success "Added volumeMounts section"
        fi
    fi
    
    return 0
}

##############################################################################
# PHASE 10: ADD VOLUMES TO MANIFEST
##############################################################################

add_volumes() {
    local manifest_file="$1"
    
    print_header "PHASE 10: Adding volumes (hostPath) for Audit"
    
    # Check if volumes section exists
    if grep -q "^  volumes:" "$manifest_file"; then
        log_success "volumes section already exists"
        
        # Check if our volumes are already there
        if grep -q "audit-log:" "$manifest_file" || grep -q "name: audit-log" "$manifest_file"; then
            log_success "audit-log volume already exists"
        else
            # Need to add to existing volumes section
            # Find the volumes line
            local vol_line=$(grep -n "^  volumes:" "$manifest_file" | head -1 | cut -d: -f1)
            
            if [[ -n "$vol_line" ]]; then
                local next_line=$((vol_line + 1))
                
                # Get indentation
                local indent="    "  # Standard K8s indentation
                
                local volumes_content="${indent}- name: audit-log\n${indent}  hostPath:\n${indent}    path: ${AUDIT_DIR}\n${indent}    type: DirectoryOrCreate\n${indent}- name: audit-policy\n${indent}  hostPath:\n${indent}    path: ${AUDIT_POLICY_PATH}\n${indent}    type: FileOrCreate"
                
                sed -i "${next_line}i\\${volumes_content}" "$manifest_file"
                log_success "Added audit volumes"
            fi
        fi
    else
        # Need to add volumes section at the end of the spec
        # Find the last line before the final newline
        local last_line=$(wc -l < "$manifest_file")
        
        local volumes_section="\n  volumes:\n    - name: audit-log\n      hostPath:\n        path: ${AUDIT_DIR}\n        type: DirectoryOrCreate\n    - name: audit-policy\n      hostPath:\n        path: ${AUDIT_POLICY_PATH}\n        type: FileOrCreate"
        
        # Append at the end
        printf '%b' "$volumes_section" >> "$manifest_file"
        log_success "Added volumes section"
    fi
    
    return 0
}

##############################################################################
# PHASE 11: SAVE AND VALIDATE MANIFEST
##############################################################################

save_and_validate() {
    local temp_file="$1"
    
    print_header "PHASE 11: Validating and Saving Manifest"
    
    # Validate YAML indentation
    if ! validate_yaml_indentation "$temp_file"; then
        log_error "YAML validation failed - not applying changes"
        return 1
    fi
    
    # Copy validated manifest to actual location
    if cp "$temp_file" "$APISERVER_MANIFEST"; then
        log_success "Manifest updated: $APISERVER_MANIFEST"
    else
        log_error "Failed to save manifest"
        return 1
    fi
    
    return 0
}

##############################################################################
# PHASE 12: VERIFY MODIFICATIONS
##############################################################################

verify_modifications() {
    print_header "PHASE 12: Verifying Modifications"
    
    local checks_passed=0
    local total_checks=0
    
    declare -a checks=(
        "audit-log-path"
        "audit-policy-file"
        "audit-log-maxage"
        "audit-log-maxbackup"
        "audit-log-maxsize"
        "name: audit-log"
        "name: audit-policy"
    )
    
    for check in "${checks[@]}"; do
        ((total_checks++))
        if grep -q "$check" "$APISERVER_MANIFEST"; then
            log_success "Verified: $check"
            ((checks_passed++))
        else
            log_warning "Not verified: $check"
        fi
    done
    
    echo ""
    log_info "Verification: $checks_passed/$total_checks checks passed"
    
    if [[ $checks_passed -eq $total_checks ]]; then
        return 0
    else
        return 1
    fi
}

##############################################################################
# PHASE 13: RESTART KUBE-APISERVER
##############################################################################

restart_kube_apiserver() {
    print_header "PHASE 13: Restarting kube-apiserver Pod"
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_warning "kubectl not found - cannot restart kube-apiserver automatically"
        return 0
    fi
    
    # Try to delete the pod to trigger restart
    if kubectl delete pod -n kube-system -l component=kube-apiserver 2>/dev/null; then
        log_success "Initiated kube-apiserver Pod restart"
        log_warning "Wait 30-60 seconds for the Pod to become ready"
    else
        log_warning "Could not delete kube-apiserver pod - manual restart may be needed"
        log_info "To restart manually, run:"
        log_info "  kubectl delete pod -n kube-system -l component=kube-apiserver"
    fi
    
    return 0
}

##############################################################################
# SUMMARY
##############################################################################

print_summary() {
    print_header "REMEDIATION SUMMARY"
    
    if [[ $ERRORS -eq 0 ]]; then
        echo -e "${GREEN}✓ REMEDIATION COMPLETED SUCCESSFULLY${NC}"
        echo ""
        echo "Key locations:"
        echo "  Audit logs:      ${AUDIT_LOG_PATH}"
        echo "  Audit policy:    ${AUDIT_POLICY_PATH}"
        echo "  Backup dir:      ${BACKUP_DIR}"
    else
        echo -e "${RED}✗ REMEDIATION FAILED${NC}"
        echo ""
        echo "Review manifest backup:"
        echo "  ${BACKUP_DIR}/kube-apiserver.yaml.backup_*"
    fi
    
    echo ""
    echo "Results:"
    echo -e "  ${GREEN}Successes: $SUCCESSES${NC}"
    echo -e "  ${YELLOW}Warnings: $WARNINGS${NC}"
    echo -e "  ${RED}Errors: $ERRORS${NC}"
    
    echo "================================================================================"
    
    if [[ $ERRORS -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

##############################################################################
# MAIN EXECUTION
##############################################################################

main() {
    echo "================================================================================"
    echo "CIS KUBERNETES AUDIT LOGGING SAFE REMEDIATION"
    echo "Version: 1.0"
    echo "================================================================================"
    echo ""
    
    # Phase 1: Check prerequisites
    if ! check_prerequisites; then
        print_summary
        return 1
    fi
    
    # Phase 2: Create backup directory
    if ! create_backup_dir; then
        print_summary
        return 1
    fi
    
    # Phase 3: Backup manifest
    if ! backup_manifest; then
        print_summary
        return 1
    fi
    
    # Phase 4: Create audit directory
    if ! create_audit_directory; then
        print_summary
        return 1
    fi
    
    # Phase 5: Create audit policy
    if ! create_audit_policy; then
        print_summary
        return 1
    fi
    
    # Load manifest
    local manifest_content
    manifest_content=$(load_manifest)
    if [[ -z "$manifest_content" ]]; then
        log_error "Failed to load manifest"
        print_summary
        return 1
    fi
    
    # Phase 8: Add flags
    if ! add_audit_flags "$manifest_content" "$TEMP_MANIFEST"; then
        log_error "Failed to add audit flags"
        print_summary
        rm -f "$TEMP_MANIFEST"
        return 1
    fi
    
    # Phase 9: Add volume mounts
    if ! add_volume_mounts "$TEMP_MANIFEST"; then
        log_warning "Failed to add volume mounts"
    fi
    
    # Phase 10: Add volumes
    if ! add_volumes "$TEMP_MANIFEST"; then
        log_warning "Failed to add volumes"
    fi
    
    # Phase 11: Save and validate
    if ! save_and_validate "$TEMP_MANIFEST"; then
        print_summary
        rm -f "$TEMP_MANIFEST"
        return 1
    fi
    
    # Clean up temp file
    rm -f "$TEMP_MANIFEST"
    
    # Phase 12: Verify modifications
    verify_modifications
    
    # Phase 13: Restart kube-apiserver
    restart_kube_apiserver
    
    # Print summary and exit
    print_summary
}

# Run main function
main
exit $?
