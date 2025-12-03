#!/bin/bash
set -xe

# CIS Benchmark: 1.2.12
# Title: Ensure that the admission control plugin ServiceAccount is set (Automated)
# Level: Level 2 - Master Node
# Description: Ensure that ServiceAccount is NOT in the --disable-admission-plugins list

SCRIPT_NAME="1.2.12_audit.sh"
echo "[INFO] Starting CIS Benchmark check: 1.2.12"

# Initialize variables
audit_passed=true
failure_reasons=()

# Verify kube-apiserver is running and get the full command line
echo "[INFO] Checking kube-apiserver process..."
if ! ps -ef | grep -v grep | grep -q "kube-apiserver"; then
    echo "[FAIL] kube-apiserver process is not running"
    exit 1
fi

echo "[INFO] Extracting kube-apiserver command line arguments..."
apiserver_cmd=$(ps -ef | grep -v grep | grep "kube-apiserver" | tr ' ' '\n')

# Check if --disable-admission-plugins is set
echo "[INFO] Checking if --disable-admission-plugins is set..."
if echo "$apiserver_cmd" | grep -F -q -- "--disable-admission-plugins"; then
    echo "[INFO] --disable-admission-plugins is set"
    
    # Extract the value of --disable-admission-plugins
    disable_plugins=$(ps -ef | grep -v grep | grep "kube-apiserver" | tr '=' '\n' | grep -A1 "^--disable-admission-plugins$" | tail -1)
    echo "[DEBUG] Extracted value: $disable_plugins"
    
    # Check if ServiceAccount is in the disabled plugins list
    if echo "$disable_plugins" | grep -F -q "ServiceAccount"; then
        echo "[FAIL] ServiceAccount is present in --disable-admission-plugins"
        audit_passed=false
        failure_reasons+=("ServiceAccount found in disabled admission plugins")
    else
        echo "[PASS] ServiceAccount is NOT in --disable-admission-plugins"
    fi
else
    echo "[PASS] --disable-admission-plugins is not set (ServiceAccount is enabled by default)"
fi

# Report final result
echo ""
echo "==============================================="
if [ "$audit_passed" = true ]; then
    echo "[PASS] CIS 1.2.12: Admission plugin ServiceAccount is correctly configured"
    exit 0
else
    echo "[FAIL] CIS 1.2.12: Admission plugin ServiceAccount is NOT correctly configured"
    echo "Reasons:"
    for reason in "${failure_reasons[@]}"; do
        echo "  - $reason"
    done
    exit 1
fi
