#!/bin/bash
set -xe

# CIS Benchmark: 5.2.9
# Title: Minimize the admission of containers with added capabilities (Automated)
# Level: Level 2 - Master Node
# Description: Ensure that containers do not have unnecessary Linux capabilities added

SCRIPT_NAME="5.2.9_audit.sh"
echo "[INFO] Starting CIS Benchmark check: 5.2.9"

# Initialize variables
audit_passed=true
failure_reasons=()
caps_pods_found=()

# Verify kubectl is available
echo "[INFO] Checking if kubectl is available..."
if ! command -v kubectl &> /dev/null; then
    echo "[FAIL] kubectl command not found"
    exit 1
fi

echo "[INFO] Fetching all pods from all namespaces..."
# Get all pods and check for added capabilities
# Exclude system namespaces: kube-system, kube-public, kube-node-lease
while IFS= read -r line; do
    [ -z "$line" ] && continue
    
    namespace=$(echo "$line" | cut -d' ' -f1)
    pod_name=$(echo "$line" | cut -d' ' -f2)
    capabilities=$(echo "$line" | cut -d' ' -f3-)
    
    echo "[DEBUG] Checking: $namespace/$pod_name (capabilities: $capabilities)"
    
    if [ "$capabilities" != "<none>" ] && [ -n "$capabilities" ]; then
        echo "[WARN] Found pod with added capabilities: $namespace/$pod_name"
        caps_pods_found+=("$namespace/$pod_name (capabilities: $capabilities)")
        audit_passed=false
    fi
done < <(kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,CAPABILITIES:'.spec.containers[*].securityContext.capabilities.add[*]' 2>/dev/null | grep -v "kube-system" | grep -v "kube-public" | grep -v "kube-node-lease" | tail -n +2)

# Final report
echo ""
echo "==============================================="
if [ "$audit_passed" = true ]; then
    echo "[PASS] CIS 5.2.9: No containers with added capabilities found in non-system namespaces"
    exit 0
else
    echo "[FAIL] CIS 5.2.9: Found containers with unnecessary Linux capabilities"
    echo "Containers requiring remediation:"
    for pod in "${caps_pods_found[@]}"; do
        echo "  - $pod"
    done
    echo ""
    echo "[INFO] Manual fix: Update pod spec to drop capabilities:"
    echo "  securityContext:"
    echo "    capabilities:"
    echo "      drop:"
    echo "      - ALL"
    exit 1
fi
