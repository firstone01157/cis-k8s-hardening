#!/bin/bash
set -xe

# CIS Benchmark: 5.6.3
# Title: Apply Security Context to Pods and Containers (Manual)
# Level: Level 2 - Master Node
# Description: Verify that security contexts are applied to pods

SCRIPT_NAME="5.6.3_audit.sh"
echo "[INFO] Starting CIS Benchmark check: 5.6.3"
echo "[INFO] This is a MANUAL CHECK - requires human review"

# Initialize variables
audit_passed=true
pods_without_context=()

# Verify kubectl is available
echo "[INFO] Checking if kubectl is available..."
if ! command -v kubectl &> /dev/null; then
    echo "[FAIL] kubectl command not found"
    exit 1
fi

echo "[INFO] Checking pods for security context..."
while IFS= read -r line; do
    [ -z "$line" ] && continue
    
    namespace=$(echo "$line" | cut -d' ' -f1)
    pod_name=$(echo "$line" | cut -d' ' -f2)
    has_context=$(echo "$line" | cut -d' ' -f3)
    
    echo "[DEBUG] Checking: $namespace/$pod_name (has securityContext: $has_context)"
    
    if [ "$has_context" != "true" ]; then
        echo "[WARN] Pod missing security context: $namespace/$pod_name"
        pods_without_context+=("$namespace/$pod_name")
        audit_passed=false
    fi
done < <(kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,HAS_SECCTX:'.spec.securityContext' 2>/dev/null | grep -v '<none>' | tail -n +2)

# Final report
echo ""
echo "==============================================="
if [ "$audit_passed" = true ]; then
    echo "[PASS] CIS 5.6.3: All pods have security contexts defined"
    echo "[INFO] Best practice: Review security context configurations"
    exit 0
else
    echo "[FAIL] CIS 5.6.3: Some pods lack security context"
    echo "Pods requiring security context:"
    for pod in "${pods_without_context[@]}"; do
        echo "  - $pod"
    done
    echo ""
    echo "[INFO] Manual fix: Add security context to pod spec:"
    echo "  spec:"
    echo "    securityContext:"
    echo "      runAsNonRoot: true"
    echo "      runAsUser: 1000"
    echo "      fsGroup: 1000"
    echo "    containers:"
    echo "    - name: app"
    echo "      securityContext:"
    echo "        allowPrivilegeEscalation: false"
    echo "        readOnlyRootFilesystem: true"
    echo "        capabilities:"
    echo "          drop:"
    echo "          - ALL"
    exit 1
fi
