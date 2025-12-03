#!/bin/bash
set -xe

# CIS Benchmark: 5.6.4
# Title: The default namespace should not be used (Manual)
# Level: Level 2 - Master Node
# Remediation: Migrate resources from default namespace

SCRIPT_NAME="5.6.4_remediate.sh"
echo "[INFO] Starting CIS Benchmark remediation: 5.6.4"
echo "[INFO] This check requires MANUAL remediation"

echo ""
echo "========================================================"
echo "[INFO] CIS 5.6.4: Namespace Segregation"
echo "========================================================"
echo ""
echo "MANUAL REMEDIATION STEPS:"
echo ""
echo "1. Identify resources in default namespace (from audit):"
echo "   ./5.6.4_audit.sh"
echo "   kubectl get all -n default"
echo ""
echo "2. Create dedicated namespaces for each application:"
echo "   kubectl create namespace production"
echo "   kubectl create namespace staging"
echo "   kubectl create namespace development"
echo "   kubectl create namespace monitoring"
echo ""
echo "3. Move resources from default to appropriate namespace:"
echo ""
echo "   # Export resource from default"
echo "   kubectl get deployment <name> -n default -o yaml > deployment.yaml"
echo ""
echo "   # Update namespace in YAML"
echo "   sed -i 's/namespace: default/namespace: production/' deployment.yaml"
echo ""
echo "   # Apply to new namespace"
echo "   kubectl apply -f deployment.yaml"
echo ""
echo "4. Verify resources in new namespace:"
echo "   kubectl get all -n production"
echo ""
echo "5. Delete from default namespace:"
echo "   kubectl delete deployment <name> -n default"
echo ""
echo "6. Configure namespace quota and limits:"
echo "   kubectl apply -f namespace-quota.yaml  # ResourceQuota"
echo "   kubectl apply -f namespace-limits.yaml # LimitRange"
echo ""
echo "[PASS] Manual remediation guidance provided"
echo "[INFO] Please complete the manual steps above"
exit 0
