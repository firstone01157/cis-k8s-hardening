#!/bin/bash
# CIS Benchmark: 5.2.2
# Title: Minimize the admission of privileged containers
# Level: • Level 1 - Master Node
# Description: Ensure Pod Security Standards (PSS) are applied to namespaces.

audit_rule() {
    echo "[INFO] Starting check for 5.2.2 (Minimize admission of privileged containers)..."
    
    # Verify kubectl and jq are available
    if ! command -v kubectl &> /dev/null; then
        echo "[FAIL] kubectl command not found"
        return 2
    fi
    
    if ! command -v jq &> /dev/null; then
        echo "[FAIL] jq command not found"
        return 2
    fi

    # Fetch namespace data
    ns_json=$(kubectl get ns -o json 2>/dev/null)
    if [ -z "$ns_json" ]; then
        echo "[FAIL] Failed to fetch namespaces from cluster"
        return 2
    fi

    # Get all target namespaces (excluding system namespaces)
    target_ns=$(echo "$ns_json" | jq -r '.items[] | select(.metadata.name != "kube-system" and .metadata.name != "kube-public" and .metadata.name != "kube-node-lease") | .metadata.name')

    failed_ns=()
    compliant_ns=()

    for ns in $target_ns; do
        # Check if ANY of the PSS labels are set to restricted or baseline
        # pod-security.kubernetes.io/enforce
        # pod-security.kubernetes.io/warn
        # pod-security.kubernetes.io/audit
        
        is_compliant=$(echo "$ns_json" | jq -r --arg ns "$ns" '
            .items[] | select(.metadata.name == $ns) | .metadata.labels | 
            (
                (."pod-security.kubernetes.io/enforce" | . == "restricted" or . == "baseline") or
                (."pod-security.kubernetes.io/warn" | . == "restricted" or . == "baseline") or
                (."pod-security.kubernetes.io/audit" | . == "restricted" or . == "baseline")
            )
        ')

        if [ "$is_compliant" = "true" ]; then
            compliant_ns+=("$ns")
        else
            failed_ns+=("$ns")
        fi
    done

    # Final Output
    if [ ${#failed_ns[@]} -eq 0 ]; then
        echo "[PASS] All target namespaces are compliant with Pod Security Standards."
        [ ${#compliant_ns[@]} -gt 0 ] && echo "[INFO] Compliant namespaces: ${compliant_ns[*]}"
        return 0
    else
        echo "[FAIL] The following namespaces are NOT compliant with Pod Security Standards (missing restricted/baseline labels):"
        for ns in "${failed_ns[@]}"; do
            echo "  - $ns"
        done
        echo "[FIX_HINT] Apply PSS labels (enforce, warn, or audit) set to 'restricted' or 'baseline' to these namespaces."
        return 1
    fi
}

audit_rule
exit $?
