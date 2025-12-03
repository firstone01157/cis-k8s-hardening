#!/bin/bash
set -xe

# CIS Benchmark: 1.2.14
# Title: Ensure that the admission control plugin NodeRestriction is set (Automated)
# Level: Level 2 - Master Node
# Description: Ensure that NodeRestriction IS in the --enable-admission-plugins list

SCRIPT_NAME="1.2.14_audit.sh"
echo "[INFO] Starting CIS Benchmark check: 1.2.14"

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
# Use grep -o to extract the exact --enable-admission-plugins=<value> pattern
# This is more robust than tr/tail which can fail if process output spans multiple lines

enable_plugins_flag=$(ps -ef | grep -v grep | grep "kube-apiserver" | grep -o -- '--enable-admission-plugins=[^ ]*')
echo "[DEBUG] Full flag: $enable_plugins_flag"

if [ -z "$enable_plugins_flag" ]; then
    echo "[FAIL] --enable-admission-plugins is not set"
    audit_passed=false
    failure_reasons+=("--enable-admission-plugins flag not found")
else
    echo "[INFO] --enable-admission-plugins is set"
    
    # Extract just the value part (after the = sign)
    # Remove the '--enable-admission-plugins=' prefix to get: NodeRestriction,AlwaysPullImages,...
    enable_plugins="${enable_plugins_flag#--enable-admission-plugins=}"
    echo "[DEBUG] Extracted plugins: $enable_plugins"
    
    # Check if NodeRestriction is in the enabled plugins list
    # Use grep -F to do literal string matching (not regex)
    if echo "$enable_plugins" | grep -F -q "NodeRestriction"; then
        echo "[INFO] NodeRestriction found in enabled plugins"
        echo "[PASS] NodeRestriction is present in --enable-admission-plugins"
    else
        echo "[FAIL] NodeRestriction is NOT in --enable-admission-plugins"
        audit_passed=false
        failure_reasons+=("NodeRestriction not found in enabled admission plugins")
    fi
fi

# Report final result
echo ""
echo "==============================================="
if [ "$audit_passed" = true ]; then
    echo "[PASS] CIS 1.2.14: Admission plugin NodeRestriction is correctly configured"
    exit 0
else
    echo "[FAIL] CIS 1.2.14: Admission plugin NodeRestriction is NOT correctly configured"
    echo "Reasons:"
    for reason in "${failure_reasons[@]}"; do
        echo "  - $reason"
    done
    exit 1
fi
