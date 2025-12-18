#!/bin/bash

# CIS Benchmark: 5.6.4
# Title: The default namespace should not be used (Manual)
# Level: Level 2 - Master Node
# SAFETY FIRST Strategy: Manual Intervention (Destructive Operation)
#
# ============================================================================
# SAFETY STRATEGY:
# - This check requires MANUAL remediation due to risk of data loss
# - Exiting with code 3 signals the test runner: "MANUAL INTERVENTION REQUIRED"
# - Prevents false positives from "fixed" when nothing was actually done
# - Print guidance for users to complete this step safely
# ============================================================================

set -o errexit
set -o pipefail

SCRIPT_NAME="5.6.4_remediate.sh"

echo "[INFO] Starting CIS Benchmark remediation: 5.6.4"
echo ""
echo "========================================================"
echo "[MANUAL] CIS 5.6.4: Default Namespace Should Not Be Used"
echo "========================================================"
echo ""
echo "RISK ASSESSMENT:"
echo "  - This remediation requires MANUAL intervention"
echo "  - Migrating resources from 'default' namespace can cause data loss"
echo "  - Deleting resources has permanent consequences"
echo "  - Automation cannot safely decide which resources to move"
echo ""
echo "REMEDIATION STEPS (MANUAL):"
echo ""
echo "1. Identify resources in default namespace:"
echo "   kubectl get all -n default"
echo "   kubectl api-resources --verbs=list --namespaced=true -o wide"
echo ""
echo "2. Create dedicated namespaces for each workload:"
echo "   kubectl create namespace production"
echo "   kubectl create namespace staging"
echo "   kubectl create namespace development"
echo ""
echo "3. Export and migrate resources from default to target namespace:"
echo "   # For each resource in default namespace:"
echo "   kubectl get <type> <name> -n default -o yaml > resource.yaml"
echo "   sed -i 's/namespace: default/namespace: production/' resource.yaml"
echo "   kubectl apply -f resource.yaml"
echo ""
echo "4. Verify resources in new namespace:"
echo "   kubectl get all -n production"
echo ""
echo "5. DELETE resources from default namespace (after verification):"
echo "   kubectl delete <type> <name> -n default"
echo ""
echo "6. Apply namespace isolation policies:"
echo "   - NetworkPolicy: restrict traffic between namespaces"
echo "   - ResourceQuota: limit resource consumption per namespace"
echo "   - RBAC: restrict access per namespace"
echo ""
echo "VERIFICATION:"
echo "   kubectl get all -n default  # Should be empty"
echo "   kubectl get ns default      # Namespace still exists"
echo ""
echo "[IMPORTANT] Audit your workloads BEFORE deleting any resources"
echo ""
echo "[MANUAL] This remediation requires human judgment and verification"
echo "[EXIT CODE 3] Indicates manual intervention required - not auto-fixed"
echo ""

exit 3
