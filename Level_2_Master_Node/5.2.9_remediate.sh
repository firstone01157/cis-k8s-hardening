#!/bin/bash
set -xe

# CIS Benchmark: 5.2.9
# Title: Minimize the admission of containers with added capabilities (Automated)
# Level: Level 2 - Master Node
# Remediation: This is a MANUAL remediation step - requires pod spec updates

SCRIPT_NAME="5.2.9_remediate.sh"
echo "[INFO] Starting CIS Benchmark remediation: 5.2.9"
echo "[INFO] This check requires MANUAL remediation"

echo ""
echo "========================================================"
echo "[INFO] CIS 5.2.9: Minimize Container Capabilities"
echo "========================================================"
echo ""
echo "MANUAL REMEDIATION STEPS:"
echo ""
echo "1. Identify containers with added capabilities (from audit script):"
echo "   ./5.2.9_audit.sh"
echo ""
echo "2. For each pod found, update its manifest to drop capabilities:"
echo "   spec:"
echo "     containers:"
echo "     - name: container-name"
echo "       securityContext:"
echo "         capabilities:"
echo "           drop:"
echo "           - ALL"
echo ""
echo "3. Or apply a Pod Security Policy at the cluster level:"
echo ""
echo "   apiVersion: policy/v1beta1"
echo "   kind: PodSecurityPolicy"
echo "   metadata:"
echo "     name: restricted"
echo "   spec:"
echo "     privileged: false"
echo "     allowPrivilegeEscalation: false"
echo "     requiredDropCapabilities:"
echo "     - ALL"
echo "     allowedCapabilities: []  # No capabilities allowed unless explicitly needed"
echo ""
echo "4. Apply the policy:"
echo "   kubectl apply -f psp-restricted.yaml"
echo ""
echo "5. Verify the policy is enforced:"
echo "   kubectl get psp"
echo ""
echo "[PASS] Manual remediation guidance provided"
echo "[INFO] Please complete the manual steps above"
exit 0
