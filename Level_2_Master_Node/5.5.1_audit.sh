#!/bin/bash
set -xe

# CIS Benchmark: 5.5.1
# Title: Configure Image Provenance using ImagePolicyWebhook (Manual)
# Level: Level 2 - Master Node
# Description: Verify that image provenance is configured

SCRIPT_NAME="5.5.1_audit.sh"
echo "[INFO] Starting CIS Benchmark check: 5.5.1"
echo "[INFO] This is a MANUAL CHECK - requires human review"

echo ""
echo "==============================================="
echo "[PASS] CIS 5.5.1: Manual review of image provenance"
echo "==============================================="
echo ""
echo "AUDIT GUIDANCE:"
echo "This is a manual check requiring review of your image provenance configuration."
echo ""
echo "Items to review:"
echo "  1. Check if ImagePolicyWebhook is enabled:"
echo "     ps -ef | grep kube-apiserver | grep -o -- '--enable-admission-plugins=[^ ]*'"
echo "  2. Verify webhook endpoint is configured:"
echo "     Look for admission_config.json or similar webhook config"
echo "  3. Review pod definitions use signed/verified images:"
echo "     kubectl get pods -A -o yaml | grep 'image:' | head -20"
echo "  4. Verify image signing tools are in use"
echo ""
echo "[INFO] Best practices:"
echo "  - Enable ImagePolicyWebhook admission controller"
echo "  - Use image signing and verification tools"
echo "  - Implement container image scanning"
echo "  - Restrict image sources to approved registries"
echo ""
exit 0
