#!/bin/bash
# CIS Kubernetes Benchmark 5.3.2 Audit Script
# Ensure that all Namespaces have a NetworkPolicy defined
# 
# This script checks if all non-system namespaces have at least one NetworkPolicy defined.
# A NetworkPolicy is considered present if any policy exists in that namespace.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# System namespaces to exclude from audit
SYSTEM_NAMESPACES=(
    "kube-system"
    "kube-public"
    "kube-node-lease"
    "kube-apiserver"
    "openshift-apiserver"
    "openshift-controller-manager"
)

# Function to check if namespace is a system namespace
is_system_namespace() {
    local ns=$1
    for sys_ns in "${SYSTEM_NAMESPACES[@]}"; do
        if [[ "$ns" == "$sys_ns" ]] || [[ "$ns" =~ ^openshift- ]] || [[ "$ns" =~ ^calico- ]] || [[ "$ns" =~ ^kube- ]]; then
            return 0
        fi
    done
    return 1
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "[ERROR] kubectl not found in PATH"
    exit 2
fi

# Get all namespaces
all_namespaces=$(kubectl get ns -o jsonpath='{.items[*].metadata.name}')

if [ -z "$all_namespaces" ]; then
    echo "[ERROR] Failed to retrieve namespaces"
    exit 2
fi

# Find namespaces without NetworkPolicy
namespaces_without_policy=()
namespaces_checked=0

for namespace in $all_namespaces; do
    # Skip system namespaces
    if is_system_namespace "$namespace"; then
        continue
    fi
    
    namespaces_checked=$((namespaces_checked + 1))
    
    # Check if namespace has any NetworkPolicy
    policy_count=$(kubectl get networkpolicy -n "$namespace" --no-headers 2>/dev/null | wc -l)
    
    if [ "$policy_count" -eq 0 ]; then
        namespaces_without_policy+=("$namespace")
    fi
done

# Determine audit result
if [ ${#namespaces_without_policy[@]} -eq 0 ]; then
    echo "[+] PASS: All $namespaces_checked checked namespaces have at least one NetworkPolicy defined"
    exit 0
else
    echo "[-] FAIL: The following $((${#namespaces_without_policy[@]})) namespace(s) do not have a NetworkPolicy defined:"
    for ns in "${namespaces_without_policy[@]}"; do
        echo "    - $ns"
    done
    echo ""
    echo "[REMEDIATION] Use: python3 $PROJECT_ROOT/network_policy_manager.py --remediate"
    exit 1
fi
