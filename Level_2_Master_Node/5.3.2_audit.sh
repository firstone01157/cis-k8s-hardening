#!/bin/bash
set -e

# CIS Benchmark: 5.3.2
# Title: Ensure that all Namespaces have Network Policies defined (AUTOMATED)
# Level: Level 2 - Master Node
# Description: Verify that all non-system namespaces have NetworkPolicies

SCRIPT_NAME="5.3.2_audit.sh"
echo "[INFO] Starting CIS Benchmark audit: 5.3.2"

# Initialize variables
audit_passed=true
namespaces_without_policy=()
namespaces_with_policy=()

# Verify kubectl is available and in PATH
if ! command -v kubectl &> /dev/null; then
    echo "[FAIL] kubectl command not found in PATH"
    exit 1
fi

echo "[INFO] Fetching all namespaces..."

# Get all namespaces except system ones
# System namespaces to exclude: kube-system, kube-public, kube-node-lease, local-path-storage
namespaces=$(kubectl get ns -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v -E '^(kube-system|kube-public|kube-node-lease|local-path-storage|default)$')

if [ -z "$namespaces" ]; then
    echo "[PASS] No custom namespaces found (only system namespaces exist)"
    exit 0
fi

echo ""
echo "=========================================="
echo "Checking NetworkPolicies in namespaces..."
echo "=========================================="
echo ""

# Check each namespace for NetworkPolicies
while IFS= read -r namespace; do
    # Skip empty lines
    [ -z "$namespace" ] && continue
    
    # Get NetworkPolicy count in this namespace
    policy_count=$(kubectl get networkpolicies -n "$namespace" --no-headers 2>/dev/null | wc -l)
    
    if [ "$policy_count" -eq 0 ]; then
        echo "[FAIL] Namespace $namespace has no NetworkPolicy"
        namespaces_without_policy+=("$namespace")
        audit_passed=false
    else
        echo "[PASS] Namespace $namespace has NetworkPolicy"
        namespaces_with_policy+=("$namespace")
    fi
done <<< "$namespaces"

# Final summary
echo ""
echo "=========================================="
echo "CIS 5.3.2 Audit Summary"
echo "=========================================="
echo "[INFO] Namespaces with NetworkPolicy: ${#namespaces_with_policy[@]}"
echo "[INFO] Namespaces without NetworkPolicy: ${#namespaces_without_policy[@]}"
echo ""

if [ "$audit_passed" = true ]; then
    echo "[PASS] CIS 5.3.2: All non-system namespaces have NetworkPolicies defined"
    echo ""
    exit 0
else
    echo "[FAIL] CIS 5.3.2: Some namespaces are missing NetworkPolicies"
    echo ""
    echo "Namespaces requiring NetworkPolicy remediation:"
    for ns in "${namespaces_without_policy[@]}"; do
        echo "  - $ns"
    done
    echo ""
    exit 1
fi
