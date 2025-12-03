#!/bin/bash
set -xe

# CIS Benchmark: 5.6.2
# Title: Ensure seccomp profile is set to RuntimeDefault (Manual)
# Level: Level 2 - Master Node
# Description: Verify that pods use RuntimeDefault seccomp profile

SCRIPT_NAME="5.6.2_audit.sh"
echo "[INFO] Starting CIS Benchmark check: 5.6.2"
echo "[INFO] This is a MANUAL CHECK - requires human review"

# Initialize variables
audit_passed=true
pods_without_seccomp=()

# Verify kubectl is available
echo "[INFO] Checking if kubectl is available..."
if ! command -v kubectl &> /dev/null; then
    echo "[FAIL] kubectl command not found"
    exit 1
fi

echo "[INFO] Checking pods for seccomp profile configuration..."
while IFS= read -r line; do
    [ -z "$line" ] && continue
    
    namespace=$(echo "$line" | cut -d' ' -f1)
    pod_name=$(echo "$line" | cut -d' ' -f2)
    seccomp=$(echo "$line" | cut -d' ' -f3)
    
    echo "[DEBUG] Checking: $namespace/$pod_name (seccomp: $seccomp)"
    
    if [ "$seccomp" != "RuntimeDefault" ]; then
        echo "[WARN] Pod missing RuntimeDefault seccomp: $namespace/$pod_name"
        pods_without_seccomp+=("$namespace/$pod_name (seccomp: $seccomp)")
        audit_passed=false
    fi
done < <(kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,SECCOMP:'.spec.securityContext.seccompProfile.type' 2>/dev/null | tail -n +2)

# Final report
echo ""
echo "==============================================="
if [ "$audit_passed" = true ]; then
    echo "[PASS] CIS 5.6.2: All pods using RuntimeDefault seccomp profile"
    exit 0
else
    echo "[FAIL] CIS 5.6.2: Some pods lack RuntimeDefault seccomp profile"
    echo "Pods requiring update:"
    for pod in "${pods_without_seccomp[@]}"; do
        echo "  - $pod"
    done
    echo ""
    echo "[INFO] Manual fix: Add seccomp profile to pod spec:"
    echo "  spec:"
    echo "    securityContext:"
    echo "      seccompProfile:"
    echo "        type: RuntimeDefault"
    exit 1
fi
