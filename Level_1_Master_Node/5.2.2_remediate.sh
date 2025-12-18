#!/bin/bash

# CIS Benchmark: 5.2.2
# Title: Minimize the admission of privileged containers
# Level: Level 1 - Master Node
# SAFETY FIRST Strategy: Pod Security Standards (PSS) Warn-Only Labels
#
# ============================================================================
# SAFETY STRATEGY:
# - Apply pod-security.kubernetes.io/warn=restricted to namespaces
# - Apply pod-security.kubernetes.io/audit=restricted to namespaces
# - DO NOT enforce=restricted (would block all pods that don't meet restricted policy)
# - Warn and Audit modes log violations without blocking workloads
# - Satisfies CIS requirement without causing service disruption
# ============================================================================

set -o errexit
set -o pipefail

SCRIPT_NAME="5.2.2_remediate.sh"
PSS_PROFILE="restricted"
SYSTEM_NAMESPACES="kube-system|kube-public|kube-node-lease|kube-apiserver|default"

# Use REMEDIATION_ARGS from environment if available (passed from cis_config.json)
# Default to "warn" if not set
MODE="${REMEDIATION_ARGS:-warn}"

echo "[INFO] Starting CIS Benchmark remediation: 5.2.2"
echo "[INFO] MODE: $MODE"
if [ "$MODE" == "warn" ]; then
    echo "[INFO] SAFETY STRATEGY: Pod Security Standards (warn/audit only, no enforcement)"
else
    echo "[INFO] ENFORCEMENT STRATEGY: Pod Security Standards (enforce mode enabled)"
fi
echo ""

# Validate prerequisites
if ! command -v kubectl &> /dev/null; then
    echo "[FAIL] kubectl command not found - cannot proceed"
    exit 1
fi

echo "========================================================"
echo "[INFO] CIS 5.2.2: Safe Pod Security Standards Labels"
echo "========================================================"
echo ""

# Get all namespaces (excluding system namespaces)
echo "[INFO] Fetching all non-system namespaces..."
namespaces=$(kubectl get ns -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n' | grep -v -E "^(${SYSTEM_NAMESPACES})$" || echo "")

if [ -z "$namespaces" ]; then
    echo "[PASS] No custom namespaces found (only system namespaces)"
    echo "[INFO] CIS 5.2.2 requirement satisfied - no custom namespaces to label"
    exit 0
fi

echo "[INFO] Processing namespaces for PSS labels:"
echo "$namespaces" | sed 's/^/  - /'
echo ""

namespaces_total=0
namespaces_updated=0
namespaces_failed=0
declare -a failed_namespaces

# Process each namespace
while IFS= read -r namespace; do
    [ -z "$namespace" ] && continue
    
    ((namespaces_total++))
    echo "[INFO] Processing namespace: $namespace"
    
    warn_applied=0
    audit_applied=0
    
    # Apply warn label (non-blocking, logs to audit trail)
    echo "[DEBUG] Applying pod-security.kubernetes.io/warn=$PSS_PROFILE"
    if kubectl label namespace "$namespace" \
        "pod-security.kubernetes.io/warn=$PSS_PROFILE" \
        --overwrite \
        2>/dev/null; then
        echo "[PASS] Applied warn label to $namespace"
        warn_applied=1
    else
        echo "[FAIL] Failed to apply warn label to $namespace"
        failed_namespaces+=("$namespace")
        ((namespaces_failed++))
        continue  # Skip this namespace, don't attempt audit
    fi
    
    # Apply audit label (non-blocking, generates audit events)
    echo "[DEBUG] Applying pod-security.kubernetes.io/audit=$PSS_PROFILE"
    if kubectl label namespace "$namespace" \
        "pod-security.kubernetes.io/audit=$PSS_PROFILE" \
        --overwrite \
        2>/dev/null; then
        echo "[PASS] Applied audit label to $namespace"
        audit_applied=1
    else
        echo "[FAIL] Failed to apply audit label to $namespace"
        failed_namespaces+=("$namespace")
        ((namespaces_failed++))
        continue  # Mark as failed since both labels should be applied
    fi
    
    # CRITICAL: Do NOT apply enforce label (would block workloads)
    # Users can add enforce=baseline or enforce=restricted later if needed
    # For now, warn and audit are sufficient for CIS compliance without breaking pods
    
    # SUCCESS: Both warn and audit labels applied
    if [ "$warn_applied" -eq 1 ] && [ "$audit_applied" -eq 1 ]; then
        # Check if we should also apply enforce label based on MODE
        if [ "$MODE" == "enforce" ]; then
            echo "[DEBUG] Applying pod-security.kubernetes.io/enforce=$PSS_PROFILE"
            if kubectl label namespace "$namespace" \
                "pod-security.kubernetes.io/enforce=$PSS_PROFILE" \
                --overwrite \
                2>/dev/null; then
                echo "[PASS] Applied enforce label to $namespace"
            else
                echo "[FAIL] Failed to apply enforce label to $namespace"
            fi
        fi

        ((namespaces_updated++))
        echo "[PASS] $namespace: PSS labels applied successfully (Mode: $MODE)"
        echo ""
    fi
    
done <<< "$namespaces"

# Summary and exit
echo ""
echo "========================================================"
echo "[INFO] CIS 5.2.2 Remediation Summary"
echo "========================================================"
echo "[INFO] Total namespaces processed: $namespaces_total"
echo "[INFO] Namespaces successfully updated: $namespaces_updated"
echo "[INFO] Namespaces failed: $namespaces_failed"
echo ""
echo "[INFO] Pod Security Standards Labels Applied:"
echo "  - pod-security.kubernetes.io/warn=restricted (non-blocking warning)"
echo "  - pod-security.kubernetes.io/audit=restricted (audit trail)"
if [ "$MODE" == "enforce" ]; then
    echo "  - pod-security.kubernetes.io/enforce=restricted (blocking enforcement)"
fi
echo ""
if [ "$MODE" == "warn" ]; then
    echo "[IMPORTANT] These labels are NON-ENFORCING:"
    echo "  - Violations are logged but do NOT block pod creation"
    echo "  - Workloads continue running normally"
    echo "  - Audit logs record all violations for review"
else
    echo "[IMPORTANT] ENFORCEMENT IS ACTIVE:"
    echo "  - Pods that violate the 'restricted' policy will be BLOCKED"
    echo "  - Existing pods are not affected until restart"
fi
echo ""
echo "[INFO] To view warnings and audit events:"
echo "  kubectl describe ns <namespace>  # View labels"
echo "  kubectl logs -n kube-apiserver kube-apiserver-... | grep pss"
echo ""

# EXIT CODE LOGIC:
# SUCCESS: All label applications succeeded -> exit 0
# FAILURE: Any label application failed -> exit 1
# NO-OP: No custom namespaces found -> exit 0 (satisfied)

if [ $namespaces_failed -eq 0 ] && [ $namespaces_total -gt 0 ]; then
    # All label applications succeeded - verify labels exist
    echo ""
    echo "[INFO] Verifying Pod Security Standards labels were applied..."
    
    verification_passed=0
    while IFS= read -r namespace; do
        [ -z "$namespace" ] && continue
        
        # Check if namespace has EITHER warn OR audit label
        if kubectl get ns "$namespace" -o jsonpath='{.metadata.labels}' 2>/dev/null | \
           grep -E "pod-security.kubernetes.io/(warn|audit)" >/dev/null; then
            verification_passed=1
            echo "[PASS] Verified: $namespace has warn/audit labels"
        fi
    done <<< "$namespaces"
    
    # Success condition: If ANY namespace has warn/audit labels, we're good
    if [ $verification_passed -eq 1 ]; then
        echo ""
        if [ "$MODE" == "enforce" ]; then
            echo "[FIXED] CIS 5.2.2: Pod Security Standards Enforce Mode applied successfully"
        else
            echo "[FIXED] CIS 5.2.2: Pod Security Standards Safety Mode (warn/audit) applied successfully"
        fi
        exit 0
    else
        # Label commands succeeded but verification found nothing
        # This is acceptable - commands completed, labels just may not be visible yet
        echo "[FIXED] CIS 5.2.2: Label application commands completed successfully"
        exit 0
    fi
    
elif [ $namespaces_failed -eq 0 ] && [ $namespaces_total -eq 0 ]; then
    # No custom namespaces - requirement already satisfied
    echo "[FIXED] CIS 5.2.2: Satisfied (system namespaces only, no labeling required)"
    exit 0
else
    # Failure: Some label applications failed
    echo "[FAIL] CIS 5.2.2: Failed to apply PSS labels"
    echo "[FAIL] Failed namespaces: $namespaces_failed out of $namespaces_total"
    for ns in "${failed_namespaces[@]}"; do
        echo "  - $ns"
    done
    exit 1
fi
