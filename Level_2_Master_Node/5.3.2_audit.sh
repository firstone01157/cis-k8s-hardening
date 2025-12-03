#!/bin/bash
set -xe

# CIS Benchmark: 5.3.2
# Title: Ensure that all Namespaces have Network Policies defined (Manual)
# Level: Level 2 - Master Node
# Description: Verify that all non-system namespaces have NetworkPolicies

SCRIPT_NAME="5.3.2_audit.sh"
echo "[INFO] Starting CIS Benchmark check: 5.3.2"

# Initialize variables
audit_passed=true
failure_reasons=()
namespaces_without_policy=()

# Verify kubectl is available
echo "[INFO] Checking if kubectl is available..."
if ! command -v kubectl &> /dev/null; then
    echo "[FAIL] kubectl command not found"
    exit 1
fi

echo "[INFO] Fetching all non-system namespaces..."
# Get all namespaces except system ones
namespaces=$(kubectl get ns -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n' | grep -v -E '^(kube-system|kube-public|kube-node-lease|default)$')

if [ -z "$namespaces" ]; then
    echo "[PASS] No custom namespaces found (only system namespaces exist)"
    exit 0
fi

echo "[INFO] Checking each namespace for NetworkPolicies..."
while IFS= read -r namespace; do
    [ -z "$namespace" ] && continue
    
    echo "[DEBUG] Checking namespace: $namespace"
    policy_count=$(kubectl get networkpolicies -n "$namespace" --no-headers 2>/dev/null | wc -l)
    echo "[DEBUG] Found $policy_count NetworkPolicies in $namespace"
    
    if [ "$policy_count" -eq 0 ]; then
        echo "[WARN] Namespace has no NetworkPolicies: $namespace"
        namespaces_without_policy+=("$namespace")
        audit_passed=false
    else
        echo "[INFO] Namespace has NetworkPolicies: $namespace"
    fi
done <<< "$namespaces"

# Final report
echo ""
echo "==============================================="
if [ "$audit_passed" = true ]; then
    echo "[PASS] CIS 5.3.2: All non-system namespaces have NetworkPolicies"
    exit 0
else
    echo "[FAIL] CIS 5.3.2: Some namespaces lack NetworkPolicies"
    echo "Namespaces requiring NetworkPolicy:"
    for ns in "${namespaces_without_policy[@]}"; do
        echo "  - $ns"
    done
    exit 1
fi
