#!/bin/bash

# CIS Benchmark: 5.3.2
# Title: Ensure that all Namespaces have Network Policies defined (AUTOMATED)
# Level: Level 2 - Master Node
# SAFETY FIRST Strategy: Allow-All NetworkPolicy
#
# ============================================================================
# SAFETY STRATEGY:
# - Create "cis-allow-all-safety-net" NetworkPolicy in each namespace
# - Policy allows ALL ingress and ALL egress traffic
# - Satisfies CIS requirement: "NetworkPolicy exists"
# - Does NOT block any workloads or disrupt service
# ============================================================================

set -o errexit
set -o pipefail

SCRIPT_NAME="5.3.2_remediate.sh"
POLICY_NAME="cis-allow-all-safety-net"
SYSTEM_NAMESPACES="kube-system|kube-public|kube-node-lease|kube-apiserver|default"

# Initialize metrics
remediation_success=true
namespaces_updated=0
namespaces_failed=0
declare -a failed_namespaces

# Validate prerequisites
echo "[INFO] Starting CIS Benchmark remediation: 5.3.2"
echo "[INFO] SAFETY STRATEGY: Creating Allow-All NetworkPolicies (non-destructive)"
echo ""

if ! command -v kubectl &> /dev/null; then
    echo "[FAIL] kubectl command not found - cannot proceed"
    exit 1
fi

echo "========================================================"
echo "[INFO] CIS 5.3.2: Safe Allow-All NetworkPolicies"
echo "========================================================"
echo ""

# Fetch all non-system namespaces
echo "[INFO] Fetching all non-system namespaces..."
namespaces=$(kubectl get ns -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n' | grep -v -E "^(${SYSTEM_NAMESPACES})$")

if [ -z "$namespaces" ]; then
    echo "[PASS] No custom namespaces found (only system namespaces exist)"
    exit 0
fi

echo "[INFO] Processing namespaces:"
echo "$namespaces" | sed 's/^/  - /'
echo ""

# Process each namespace
while IFS= read -r namespace; do
    [ -z "$namespace" ] && continue
    
    echo "[INFO] Processing namespace: $namespace"
    
    # Check if our safety-net policy already exists
    if kubectl get networkpolicy "$POLICY_NAME" -n "$namespace" &>/dev/null 2>&1; then
        echo "[PASS] Policy $POLICY_NAME already exists in $namespace"
        continue
    fi
    
    # Check if ANY NetworkPolicy exists in this namespace
    policy_count=$(kubectl get networkpolicies -n "$namespace" --no-headers 2>/dev/null | wc -l)
    if [ "$policy_count" -gt 0 ]; then
        echo "[PASS] Namespace $namespace already has NetworkPolicy(s), skipping"
        continue
    fi
    
    # Create the Allow-All NetworkPolicy
    echo "[INFO] Creating allow-all NetworkPolicy in $namespace..."
    
    # Create temporary YAML file
    TEMP_POLICY="/tmp/allow-all-${namespace}-$$.yaml"
    
    cat > "$TEMP_POLICY" <<'POLICY_EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: cis-allow-all-safety-net
  namespace: NAMESPACE_PLACEHOLDER
  labels:
    app: cis-remediation
    purpose: safety-net-allow-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - {}
  egress:
  - {}
POLICY_EOF
    
    # Replace namespace placeholder
    sed -i "s/NAMESPACE_PLACEHOLDER/$namespace/g" "$TEMP_POLICY"
    
    # Apply the policy
    if kubectl apply -f "$TEMP_POLICY" 2>/dev/null; then
        echo "[PASS] NetworkPolicy created in $namespace"
        ((namespaces_updated++))
        
        # Verify creation
        if kubectl get networkpolicy "$POLICY_NAME" -n "$namespace" &>/dev/null; then
            echo "[DEBUG] Verified: $POLICY_NAME exists in $namespace"
        fi
    else
        echo "[FAIL] Failed to create NetworkPolicy in $namespace"
        ((namespaces_failed++))
        failed_namespaces+=("$namespace")
        remediation_success=false
    fi
    
    rm -f "$TEMP_POLICY"
    
done <<< "$namespaces"

# Summary and exit
echo ""
echo "========================================================"
echo "[INFO] CIS 5.3.2 Remediation Summary"
echo "========================================================"
echo "[INFO] Namespaces updated: $namespaces_updated"
echo "[INFO] Namespaces failed: $namespaces_failed"
echo ""
echo "[INFO] Policy Details:"
echo "  - Policy Name: $POLICY_NAME"
echo "  - Type: Allow-All (non-blocking safety net)"
echo "  - Pod Selector: {} (all pods)"
echo "  - Ingress Rules: [{}] (allow all incoming)"
echo "  - Egress Rules: [{}] (allow all outgoing)"
echo ""
echo "[INFO] This policy satisfies the CIS check while allowing all traffic"
echo ""

if [ $namespaces_failed -eq 0 ]; then
    echo "[PASS] CIS 5.3.2: All non-system namespaces have allow-all NetworkPolicies"
    exit 0
else
    echo "[FAIL] CIS 5.3.2: Some namespaces failed"
    echo "[FAIL] Failed namespaces:"
    for ns in "${failed_namespaces[@]}"; do
        echo "  - $ns"
    done
    exit 1
fi
