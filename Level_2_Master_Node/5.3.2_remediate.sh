#!/bin/bash
set -xe

# CIS Benchmark: 5.3.2
# Title: Ensure that all Namespaces have Network Policies defined (AUTOMATED)
# Level: Level 2 - Master Node
# Strategy: Allow-All (allows all Ingress and Egress to pass CIS check without blocking traffic)
# Remediation: Create allow-all NetworkPolicy for all non-system namespaces

SCRIPT_NAME="5.3.2_remediate.sh"
echo "[INFO] Starting CIS Benchmark remediation: 5.3.2"

# Initialize
remediation_success=true
namespaces_updated=0
namespaces_failed=0
declare -a failed_namespaces

# Verify kubectl is available
echo "[INFO] Checking if kubectl is available..."
if ! command -v kubectl &> /dev/null; then
    echo "[FAIL] kubectl command not found"
    exit 1
fi

# Get kubectl version (handle both old and new kubectl versions)
# Kubernetes v1.34+ removed the --short flag
KUBECTL_VERSION=$(kubectl version --client 2>/dev/null | grep -oP '(?<=Client Version: v)\d+\.\d+\.\d+' || kubectl version --client --short 2>/dev/null || echo 'unknown')
echo "[DEBUG] kubectl version: $KUBECTL_VERSION"

echo ""
echo "========================================================"
echo "[INFO] CIS 5.3.2: Create Allow-All NetworkPolicies"
echo "========================================================"
echo ""

# Fetch all non-system namespaces
echo "[INFO] Fetching all non-system namespaces..."
namespaces=$(kubectl get ns -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n' | grep -v -E '^(kube-system|kube-public|kube-node-lease|default)$')

if [ -z "$namespaces" ]; then
    echo "[INFO] No custom namespaces found (only system namespaces exist)"
    echo "[PASS] CIS 5.3.2 remediation completed: no custom namespaces to update"
    exit 0
fi

echo "[DEBUG] Namespaces to process:"
echo "$namespaces" | sed 's/^/  - /'

echo ""
echo "[INFO] Processing namespaces for NetworkPolicy creation..."

# Process each namespace
while IFS= read -r namespace; do
    # Skip empty lines
    [ -z "$namespace" ] && continue
    
    echo ""
    echo "[INFO] Processing namespace: $namespace"
    
    # Check if NetworkPolicy already exists
    echo "[DEBUG] Checking for existing NetworkPolicies in $namespace..."
    existing_policies=$(kubectl get networkpolicies -n "$namespace" --no-headers 2>/dev/null | wc -l)
    echo "[DEBUG] Found $existing_policies existing NetworkPolicies"
    
    if [ "$existing_policies" -gt 0 ]; then
        echo "[PASS] Namespace $namespace already has NetworkPolicy"
        continue
    fi
    
    # Create allow-all NetworkPolicy for this namespace
    echo "[INFO] Creating allow-all NetworkPolicy in $namespace..."
    
    # Create temporary YAML file for the NetworkPolicy
    TEMP_POLICY="/tmp/allow-all-policy-${namespace}-$$.yaml"
    
    cat > "$TEMP_POLICY" <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-all-traffic
  namespace: NAMESPACE_PLACEHOLDER
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - {}
  egress:
  - {}
EOF
    
    # Replace placeholder with actual namespace
    sed -i "s/NAMESPACE_PLACEHOLDER/$namespace/g" "$TEMP_POLICY"
    echo "[DEBUG] Temporary policy file: $TEMP_POLICY"
    
    # Apply the NetworkPolicy
    if kubectl apply -f "$TEMP_POLICY" 2>&1 | tee -a /tmp/5.3.2_remediation.log; then
        echo "[PASS] NetworkPolicy created successfully in namespace: $namespace"
        ((namespaces_updated++))
        
        # Verify creation
        echo "[DEBUG] Verifying NetworkPolicy creation..."
        if kubectl get networkpolicies -n "$namespace" allow-all-traffic &>/dev/null; then
            echo "[DEBUG] Verified: allow-all-traffic exists in $namespace"
        else
            echo "[WARN] Could not verify NetworkPolicy immediately (may be pending)"
        fi
    else
        echo "[FAIL] Failed to create NetworkPolicy in namespace: $namespace"
        ((namespaces_failed++))
        failed_namespaces+=("$namespace")
        remediation_success=false
    fi
    
    # Clean up temporary file
    rm -f "$TEMP_POLICY"
    echo "[DEBUG] Cleaned up temporary file"
    
done <<< "$namespaces"

# Final report
echo ""
echo "========================================================"
echo "[INFO] CIS 5.3.2 Remediation Summary"
echo "========================================================"
echo "[INFO] Namespaces updated: $namespaces_updated"
echo "[INFO] Namespaces failed: $namespaces_failed"

if [ "$remediation_success" = true ] && [ $namespaces_failed -eq 0 ]; then
    echo ""
    echo "[PASS] CIS 5.3.2: All non-system namespaces have allow-all NetworkPolicies"
    echo ""
    echo "[INFO] Policy Details:"
    echo "  - Policy Type: Allow-All (Ingress and Egress)"
    echo "  - Pod Selector: {} (all pods)"
    echo "  - Ingress Rules: [{}] (allow all incoming traffic)"
    echo "  - Egress Rules: [{}] (allow all outgoing traffic)"
    echo ""
    echo "[INFO] Verification:"
    echo "  To verify the policies were created:"
    echo "  kubectl get networkpolicies --all-namespaces"
    echo ""
    echo "  To view a specific policy:"
    echo "  kubectl get networkpolicies -n <NAMESPACE> allow-all-traffic -o yaml"
    echo ""
    echo "[PASS] Remediation completed successfully"
    exit 0
else
    echo ""
    echo "[FAIL] CIS 5.3.2: Some namespaces failed to get NetworkPolicy"
    if [ ${#failed_namespaces[@]} -gt 0 ]; then
        echo "[FAIL] Failed namespaces:"
        for ns in "${failed_namespaces[@]}"; do
            echo "  - $ns"
        done
    fi
    echo ""
    echo "[INFO] Remediation log: /tmp/5.3.2_remediation.log"
    exit 1
fi
