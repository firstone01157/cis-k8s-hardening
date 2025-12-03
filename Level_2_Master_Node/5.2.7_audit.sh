#!/bin/bash
set -xe

# CIS Benchmark: 5.2.7
# Title: Minimize the admission of root containers (Automated)
# Level: Level 2 - Master Node
# Description: Ensure that pods in non-system namespaces do not run as root

SCRIPT_NAME="5.2.7_audit.sh"
echo "[INFO] Starting CIS Benchmark check: 5.2.7"

# Initialize variables
audit_passed=true
failure_reasons=()
root_pods_found=()

# Verify kubectl is available
echo "[INFO] Checking if kubectl is available..."
if ! command -v kubectl &> /dev/null; then
    echo "[FAIL] kubectl command not found"
    exit 1
fi

echo "[INFO] Fetching all pods from all namespaces..."
# Get all pods and check for root containers
# Exclude system namespaces: kube-system, kube-public, kube-node-lease
while IFS= read -r line; do
    [ -z "$line" ] && continue
    
    namespace=$(echo "$line" | cut -d' ' -f1)
    pod_name=$(echo "$line" | cut -d' ' -f2)
    run_as_root=$(echo "$line" | cut -d' ' -f3)
    
    echo "[DEBUG] Checking: $namespace/$pod_name (runAsNonRoot: $run_as_root)"
    
    if [ "$run_as_root" = "false" ] || [ "$run_as_root" = "NOT_SET" ]; then
        echo "[WARN] Found pod running as root: $namespace/$pod_name"
        root_pods_found+=("$namespace/$pod_name (runAsNonRoot: $run_as_root)")
        audit_passed=false
    fi
done < <(kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,RUN_AS_NON_ROOT:.spec.securityContext.runAsNonRoot 2>/dev/null | grep -v "kube-system" | grep -v "kube-public" | grep -v "kube-node-lease" | tail -n +2)

# Final report
echo ""
echo "==============================================="
if [ "$audit_passed" = true ]; then
    echo "[PASS] CIS 5.2.7: No pods running as root found in non-system namespaces"
    exit 0
else
    echo "[FAIL] CIS 5.2.7: Found pods running with root privileges"
    echo "Pods requiring remediation:"
    for pod in "${root_pods_found[@]}"; do
        echo "  - $pod"
    done
    echo ""
    echo "[INFO] Manual fix: Update pod spec to include:"
    echo "  securityContext:"
    echo "    runAsNonRoot: true"
    exit 1
fi
