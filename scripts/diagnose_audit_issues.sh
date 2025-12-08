#!/bin/bash
#
# Audit Remediation Diagnostic Script
# Comprehensive troubleshooting and issue analysis
#

set -o pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Output file
OUTPUT_FILE="audit_remediation_diagnostic_$(date +%Y%m%d_%H%M%S).txt"

print_header() {
    echo ""
    echo "================================================================================"
    echo "$1"
    echo "================================================================================"
    echo ""
}

print_section() {
    echo ""
    echo -e "${CYAN}>>> $1${NC}"
    echo "---"
}

log_output() {
    echo "$@" | tee -a "$OUTPUT_FILE"
}

collect_system_info() {
    print_header "SYSTEM INFORMATION"
    
    log_output "Hostname: $(hostname)"
    log_output "Kernel: $(uname -r)"
    log_output "OS: $(grep '^NAME=' /etc/os-release | cut -d= -f2)"
    log_output "Date/Time: $(date)"
    log_output "Bash Version: $BASH_VERSION"
    
    if command -v kubelet &> /dev/null; then
        log_output "Kubelet Version: $(kubelet --version)"
    fi
    
    if command -v kubectl &> /dev/null; then
        # Handle both old kubectl versions (with --short flag) and new ones (v1.34+)
        local kubectl_version
        kubectl_version=$(kubectl version --client 2>/dev/null | grep -oP '(?<=Client Version: v)\d+\.\d+\.\d+' || kubectl version --client --short 2>/dev/null || echo 'unknown')
        log_output "kubectl Version: $kubectl_version"
    fi
}

check_prerequisites() {
    print_section "Prerequisites Check"
    
    log_output "Current User: $(whoami)"
    log_output "UID: $(id -u)"
    log_output "EUID: $EUID"
    
    if [[ $EUID -eq 0 ]]; then
        log_output -e "${GREEN}✓ Running as root${NC}"
    else
        log_output -e "${RED}✗ NOT running as root${NC}"
    fi
    
    log_output ""
    log_output "Manifest Directory: /etc/kubernetes/manifests"
    if [[ -d "/etc/kubernetes/manifests" ]]; then
        log_output -e "${GREEN}✓ Directory exists${NC}"
        ls -la /etc/kubernetes/manifests/ | tee -a "$OUTPUT_FILE"
    else
        log_output -e "${RED}✗ Directory does NOT exist${NC}"
    fi
    
    log_output ""
    log_output "kube-apiserver Manifest: /etc/kubernetes/manifests/kube-apiserver.yaml"
    if [[ -f "/etc/kubernetes/manifests/kube-apiserver.yaml" ]]; then
        log_output -e "${GREEN}✓ File exists${NC}"
        log_output "Size: $(stat -c%s /etc/kubernetes/manifests/kube-apiserver.yaml) bytes"
        log_output "Last Modified: $(stat -c%y /etc/kubernetes/manifests/kube-apiserver.yaml)"
    else
        log_output -e "${RED}✗ File does NOT exist${NC}"
    fi
}

check_audit_directories() {
    print_section "Audit Directory Structure"
    
    log_output "Checking /var/log/kubernetes/audit..."
    
    if [[ -d "/var/log/kubernetes/audit" ]]; then
        log_output -e "${GREEN}✓ Directory exists${NC}"
        
        log_output ""
        log_output "Permissions:"
        ls -ld /var/log/kubernetes/audit | tee -a "$OUTPUT_FILE"
        
        log_output ""
        log_output "Contents:"
        ls -lah /var/log/kubernetes/audit/ | tee -a "$OUTPUT_FILE"
        
        log_output ""
        log_output "Disk Usage:"
        du -sh /var/log/kubernetes/audit/ | tee -a "$OUTPUT_FILE"
    else
        log_output -e "${RED}✗ Directory does NOT exist${NC}"
    fi
    
    log_output ""
    log_output "Checking Audit Policy File..."
    if [[ -f "/var/log/kubernetes/audit/audit-policy.yaml" ]]; then
        log_output -e "${GREEN}✓ File exists${NC}"
        log_output "Size: $(stat -c%s /var/log/kubernetes/audit/audit-policy.yaml) bytes"
        log_output ""
        log_output "Content:"
        cat /var/log/kubernetes/audit/audit-policy.yaml | tee -a "$OUTPUT_FILE"
    else
        log_output -e "${RED}✗ File does NOT exist${NC}"
    fi
}

check_manifest_content() {
    print_section "kube-apiserver Manifest Content Analysis"
    
    if [[ ! -f "/etc/kubernetes/manifests/kube-apiserver.yaml" ]]; then
        log_output -e "${RED}✗ Manifest file not found${NC}"
        return 1
    fi
    
    log_output "Full Manifest (first 100 lines):"
    head -100 /etc/kubernetes/manifests/kube-apiserver.yaml | tee -a "$OUTPUT_FILE"
    
    log_output ""
    print_section "Audit Logging Flags"
    
    for flag in "audit-log-path" "audit-policy-file" "audit-log-maxage" "audit-log-maxbackup" "audit-log-maxsize"; do
        log_output ""
        log_output "Checking flag: --$flag"
        
        if grep -q -- "--$flag" /etc/kubernetes/manifests/kube-apiserver.yaml; then
            log_output -e "${GREEN}✓ Flag found${NC}"
            log_output "Context:"
            grep -- "--$flag" /etc/kubernetes/manifests/kube-apiserver.yaml | tee -a "$OUTPUT_FILE"
        else
            log_output -e "${RED}✗ Flag NOT found${NC}"
        fi
    done
    
    log_output ""
    print_section "volumeMounts Section"
    
    if grep -q "volumeMounts:" /etc/kubernetes/manifests/kube-apiserver.yaml; then
        log_output -e "${GREEN}✓ volumeMounts section found${NC}"
        log_output ""
        grep -A 20 "volumeMounts:" /etc/kubernetes/manifests/kube-apiserver.yaml | tee -a "$OUTPUT_FILE"
    else
        log_output -e "${RED}✗ volumeMounts section NOT found${NC}"
    fi
    
    log_output ""
    print_section "volumes Section"
    
    if grep -q "^  volumes:" /etc/kubernetes/manifests/kube-apiserver.yaml; then
        log_output -e "${GREEN}✓ volumes section found${NC}"
        log_output ""
        grep -A 20 "^  volumes:" /etc/kubernetes/manifests/kube-apiserver.yaml | tee -a "$OUTPUT_FILE"
    else
        log_output -e "${RED}✗ volumes section NOT found${NC}"
    fi
}

check_yaml_validity() {
    print_section "YAML Syntax Validation"
    
    local manifest="/etc/kubernetes/manifests/kube-apiserver.yaml"
    
    if [[ ! -f "$manifest" ]]; then
        log_output -e "${RED}✗ Manifest not found${NC}"
        return 1
    fi
    
    # Check for tabs
    log_output "Checking for tabs in YAML..."
    if grep -q $'\t' "$manifest"; then
        log_output -e "${RED}✗ Found TAB characters (YAML requires spaces only)${NC}"
        grep -n $'\t' "$manifest" | head -10 | tee -a "$OUTPUT_FILE"
    else
        log_output -e "${GREEN}✓ No TAB characters found${NC}"
    fi
    
    # Check with Python YAML parser
    log_output ""
    log_output "Validating with Python YAML parser..."
    
    if command -v python3 &> /dev/null; then
        python3 << PYSCRIPT > /dev/null 2>&1
import yaml
import sys
try:
    with open('$manifest', 'r') as f:
        data = yaml.safe_load(f)
    print("YAML is valid")
    sys.exit(0)
except yaml.YAMLError as e:
    print(f"YAML Error: {e}")
    sys.exit(1)
except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)
PYSCRIPT
        
        if [[ $? -eq 0 ]]; then
            log_output -e "${GREEN}✓ YAML syntax is valid${NC}"
        else
            log_output -e "${RED}✗ YAML syntax is INVALID${NC}"
            python3 << PYSCRIPT 2>&1 | tee -a "$OUTPUT_FILE"
import yaml
try:
    with open('$manifest', 'r') as f:
        yaml.safe_load(f)
except Exception as e:
    print(f"Error details: {e}")
PYSCRIPT
        fi
    else
        log_output "Python3 not available for YAML validation"
    fi
    
    # Check indentation consistency
    log_output ""
    log_output "Checking indentation consistency..."
    
    awk '
    BEGIN { errors = 0 }
    {
        # Skip empty lines
        if ($0 ~ /^[ ]*$/) next
        
        # Get leading spaces
        match($0, /^[ ]*/)
        indent = RLENGTH - 1
        
        # Check if indent is multiple of 2
        if (indent > 0 && indent % 2 != 0) {
            printf "Line %d: Non-standard indentation (%d spaces)\n", NR, indent
            errors++
        }
    }
    END { 
        if (errors == 0) {
            print "Indentation is consistent (multiples of 2)"
        } else {
            print "Found " errors " indentation errors"
        }
    }
    ' "$manifest" | tee -a "$OUTPUT_FILE"
}

check_processes() {
    print_section "Process Status"
    
    log_output "Checking kube-apiserver process..."
    if pgrep -f "kube-apiserver" > /dev/null; then
        log_output -e "${GREEN}✓ kube-apiserver process is running${NC}"
        log_output ""
        log_output "Process details:"
        ps aux | grep kube-apiserver | grep -v grep | tee -a "$OUTPUT_FILE"
    else
        log_output -e "${RED}✗ kube-apiserver process is NOT running${NC}"
    fi
    
    log_output ""
    log_output "Checking kubelet process..."
    if pgrep -f "kubelet" > /dev/null; then
        log_output -e "${GREEN}✓ kubelet process is running${NC}"
        ps aux | grep kubelet | grep -v grep | head -1 | tee -a "$OUTPUT_FILE"
    else
        log_output -e "${RED}✗ kubelet process is NOT running${NC}"
    fi
}

check_kubernetes_cluster() {
    print_section "Kubernetes Cluster Status"
    
    if ! command -v kubectl &> /dev/null; then
        log_output "kubectl not available"
        return 1
    fi
    
    # Check nodes
    log_output "Node Status:"
    kubectl get nodes -o wide 2>&1 | tee -a "$OUTPUT_FILE"
    
    log_output ""
    log_output "kube-apiserver Pod Status:"
    kubectl get pod -n kube-system -l component=kube-apiserver -o wide 2>&1 | tee -a "$OUTPUT_FILE"
    
    log_output ""
    log_output "kube-apiserver Pod Details:"
    kubectl describe pod -n kube-system -l component=kube-apiserver 2>&1 | head -50 | tee -a "$OUTPUT_FILE"
    
    log_output ""
    log_output "kube-apiserver Pod Logs (last 50 lines):"
    kubectl logs -n kube-system -l component=kube-apiserver --tail=50 2>&1 | tee -a "$OUTPUT_FILE"
}

check_backups() {
    print_section "Backup Status"
    
    log_output "Checking backup directory: /var/backups/kubernetes"
    
    if [[ -d "/var/backups/kubernetes" ]]; then
        log_output -e "${GREEN}✓ Backup directory exists${NC}"
        log_output ""
        ls -lah /var/backups/kubernetes/ | tee -a "$OUTPUT_FILE"
    else
        log_output -e "${YELLOW}⚠ Backup directory does NOT exist${NC}"
    fi
}

check_disk_space() {
    print_section "Disk Space"
    
    log_output "Root filesystem:"
    df -h / | tee -a "$OUTPUT_FILE"
    
    log_output ""
    log_output "Kubernetes directories:"
    df -h /etc/kubernetes/ 2>/dev/null || log_output "  /etc/kubernetes not on separate partition"
    
    log_output ""
    log_output "Audit directory:"
    df -h /var/log/ 2>/dev/null | tee -a "$OUTPUT_FILE"
}

check_network() {
    print_section "Network Configuration"
    
    log_output "Checking API server connectivity..."
    
    if curl -s --cacert /etc/kubernetes/pki/ca.crt \
            --key /etc/kubernetes/pki/apiserver-kubelet-client.key \
            --cert /etc/kubernetes/pki/apiserver-kubelet-client.crt \
            https://127.0.0.1:6443/healthz > /dev/null 2>&1; then
        log_output -e "${GREEN}✓ API server is responding${NC}"
    else
        log_output -e "${RED}✗ API server is NOT responding${NC}"
    fi
}

check_audit_logs() {
    print_section "Audit Log Analysis"
    
    if [[ ! -f "/var/log/kubernetes/audit/audit.log" ]]; then
        log_output "No audit logs found yet (expected on first run)"
        return 0
    fi
    
    log_output "Audit log file size:"
    ls -lh /var/log/kubernetes/audit/audit.log* | tee -a "$OUTPUT_FILE"
    
    log_output ""
    log_output "Audit log sample (last 5 entries):"
    tail -5 /var/log/kubernetes/audit/audit.log | jq . 2>/dev/null | tee -a "$OUTPUT_FILE" || \
        tail -5 /var/log/kubernetes/audit/audit.log | tee -a "$OUTPUT_FILE"
}

main() {
    echo -e "${MAGENTA}"
    cat << 'BANNER'
  ___         _   _ _     ____                          _ _       _   _             
 / _ \       | | (_) |   |  _ \ ___ _ __ ___   ___  __| (_) __ _| |_(_) ___  _ __  
| | | |  _   | | | | |   | |_) / _ \ '_ ` _ \ / _ \/ _` | |/ _` | __| |/ _ \| '_ \ 
| |_| | | |  | |_| | |   |  _ <  __/ | | | | |  __/ (_| | | (_| | |_| | (_) | | | |
 \__\_\  |_|  \___/|_|   |_| \_\___|_| |_| |_|\___|\__,_|_|\__,_|\__|_|\___/|_| |_|
   
Diagnostic Script for Audit Remediation Issues
    BANNER
    echo -e "${NC}"
    
    log_output "================================================================================"
    log_output "AUDIT REMEDIATION DIAGNOSTIC REPORT"
    log_output "Generated: $(date)"
    log_output "================================================================================"
    
    # Run all diagnostic checks
    collect_system_info
    check_prerequisites
    check_audit_directories
    check_manifest_content
    check_yaml_validity
    check_processes
    check_kubernetes_cluster
    check_backups
    check_disk_space
    check_network
    check_audit_logs
    
    # Final summary
    print_header "DIAGNOSTIC COMPLETE"
    
    log_output "Report saved to: $OUTPUT_FILE"
    log_output ""
    log_output "Next steps:"
    log_output "1. Review output above for any RED [✗] or YELLOW [⚠] items"
    log_output "2. If kube-apiserver is not running, check kubelet logs:"
    log_output "   journalctl -u kubelet -n 100 | grep -i error"
    log_output "3. If YAML is invalid, check manifest backups:"
    log_output "   ls -la /var/backups/kubernetes/"
    log_output "4. For detailed troubleshooting, review the full report file"
    log_output ""
    
    echo "Report saved to: $OUTPUT_FILE"
}

# Run diagnostics
main
