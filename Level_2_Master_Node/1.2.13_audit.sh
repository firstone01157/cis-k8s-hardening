#!/bin/bash
set -xe

# CIS Benchmark: 1.2.13
# Title: Ensure that the admission control plugin NamespaceLifecycle is set (Automated)
# Level: Level 2 - Master Node
# Description: Ensure that NamespaceLifecycle is NOT in the --disable-admission-plugins list

SCRIPT_NAME="1.2.13_audit.sh"
echo "[INFO] Starting CIS Benchmark check: 1.2.13"

# Initialize variables
audit_passed=true
failure_reasons=()

# Verify kube-apiserver is running
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
    
    # Extract the value
    disable_plugins=$(ps -ef | grep -v grep | grep "kube-apiserver" | tr '=' '\n' | grep -A1 "^--disable-admission-plugins$" | tail -1)
    echo "[DEBUG] Extracted value: $disable_plugins"
    
    # Check if NamespaceLifecycle is in the disabled plugins list
    if echo "$disable_plugins" | grep -F -q "NamespaceLifecycle"; then
        echo "[FAIL] NamespaceLifecycle is present in --disable-admission-plugins"
        audit_passed=false
        failure_reasons+=("NamespaceLifecycle found in disabled admission plugins")
    else
        echo "[PASS] NamespaceLifecycle is NOT in --disable-admission-plugins"
    fi
else
    echo "[PASS] --disable-admission-plugins is not set (NamespaceLifecycle is enabled by default)"
fi

# Report final result
echo ""
echo "==============================================="
if [ "$audit_passed" = true ]; then
    echo "[PASS] CIS 1.2.13: Admission plugin NamespaceLifecycle is correctly configured"
    exit 0
else
    echo "[FAIL] CIS 1.2.13: Admission plugin NamespaceLifecycle is NOT correctly configured"
    echo "Reasons:"
    for reason in "${failure_reasons[@]}"; do
        echo "  - $reason"
    done
    exit 1
fi
