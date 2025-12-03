#!/bin/bash
set -xe

# CIS Benchmark: 5.6.2
# Title: Ensure seccomp profile is set to RuntimeDefault (Manual)
# Level: Level 2 - Master Node
# Remediation: This is a MANUAL remediation step

SCRIPT_NAME="5.6.2_remediate.sh"
echo "[INFO] Starting CIS Benchmark remediation: 5.6.2"
echo "[INFO] This check requires MANUAL remediation"

echo ""
echo "========================================================"
echo "[INFO] CIS 5.6.2: Seccomp Profile Configuration"
echo "========================================================"
echo ""
echo "MANUAL REMEDIATION STEPS:"
echo ""
echo "1. Identify pods without RuntimeDefault seccomp (from audit):"
echo "   ./5.6.2_audit.sh"
echo ""
echo "2. Create a seccomp profile (or use runtime default):"
echo ""
echo "3. Update pod definitions to include seccomp:"
echo ""
echo "   spec:"
echo "     securityContext:"
echo "       seccompProfile:"
echo "         type: RuntimeDefault"
echo ""
echo "   OR use a custom profile:"
echo ""
echo "     spec:"
echo "       securityContext:"
echo "         seccompProfile:"
echo "           type: Localhost"
echo "           localhostProfile: my-seccomp-profile.json"
echo ""
echo "4. Apply the updated pod specification:"
echo "   kubectl apply -f updated-pod.yaml"
echo ""
echo "5. Verify seccomp is applied:"
echo "   kubectl get pods -A -o jsonpath='{range .items[*]}{@.metadata.name}: {@..seccompProfile.type}{\"\\n\"}{end}'"
echo ""
echo "[PASS] Manual remediation guidance provided"
echo "[INFO] Please complete the manual steps above"
exit 0
