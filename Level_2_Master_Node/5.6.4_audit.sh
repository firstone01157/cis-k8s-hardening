#!/bin/bash
set -xe

# CIS Benchmark: 5.6.4
# Title: The default namespace should not be used (Manual)
# Level: Level 2 - Master Node
# Description: Verify that the default namespace is not used for workloads

SCRIPT_NAME="5.6.4_audit.sh"
echo "[INFO] Starting CIS Benchmark check: 5.6.4"
echo "[INFO] This is a MANUAL CHECK - checking default namespace for non-system resources"

# Initialize variables
audit_passed=true
resources_in_default=()

# Verify kubectl is available
echo "[INFO] Checking if kubectl is available..."
if ! command -v kubectl &> /dev/null; then
    echo "[FAIL] kubectl command not found"
    exit 1
fi

echo "[INFO] Checking default namespace for user-deployed resources..."
echo "[DEBUG] Running: kubectl get all -n default"
default_resources=$(kubectl get all -n default -o custom-columns=KIND:.kind,NAME:.metadata.name 2>/dev/null || true)

if [ -n "$default_resources" ]; then
    echo "[WARN] Found resources in default namespace:"
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        # Skip header
        if [[ "$line" == "KIND"* ]]; then
            continue
        fi
        echo "[DEBUG] Resource: $line"
        resources_in_default+=("$line")
    done <<< "$default_resources"
    
    # Only fail if non-system resources are found
    if [ ${#resources_in_default[@]} -gt 0 ]; then
        audit_passed=false
        echo "[FAIL] Non-system resources found in default namespace"
    fi
else
    echo "[PASS] No resources in default namespace"
fi

# Final report
echo ""
echo "==============================================="
if [ "$audit_passed" = true ]; then
    echo "[PASS] CIS 5.6.4: Default namespace is not used for user workloads"
    exit 0
else
    echo "[FAIL] CIS 5.6.4: User workloads found in default namespace"
    echo "Resources to migrate:"
    for resource in "${resources_in_default[@]}"; do
        echo "  - $resource"
    done
    echo ""
    echo "[INFO] Manual remediation steps:"
    echo "  1. Create dedicated namespaces for applications:"
    echo "     kubectl create namespace my-app"
    echo "     kubectl create namespace my-database"
    echo "  2. Move resources from default to appropriate namespaces:"
    echo "     kubectl get <resource> -n default -o yaml | kubectl apply -n <new-ns> -f -"
    echo "  3. Delete resources from default namespace:"
    echo "     kubectl delete <resource> --all -n default"
    exit 1
fi
