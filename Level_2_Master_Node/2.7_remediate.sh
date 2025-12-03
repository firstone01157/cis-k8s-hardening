#!/bin/bash
set -xe

# CIS Benchmark: 2.7
# Title: Ensure that a unique Certificate Authority is used for etcd (Manual)
# Level: Level 2 - Master Node
# Remediation: This is a MANUAL remediation step

SCRIPT_NAME="2.7_remediate.sh"
echo "[INFO] Starting CIS Benchmark remediation: 2.7"
echo "[INFO] This check requires MANUAL remediation"

# This is a manual check - provide guidance only
echo ""
echo "========================================================"
echo "[INFO] CIS 2.7: Unique Certificate Authority for etcd"
echo "========================================================"
echo ""
echo "MANUAL REMEDIATION STEPS:"
echo ""
echo "1. Review current etcd and kube-apiserver CA configuration:"
echo "   etcd CA:        ps -ef | grep etcd | grep -o -- '--trusted-ca-file=[^ ]*'"
echo "   apiserver CA:   ps -ef | grep kube-apiserver | grep -o -- '--client-ca-file=[^ ]*'"
echo ""
echo "2. If the CA files are the same, follow these steps:"
echo "   a. Generate a new certificate authority for etcd:"
echo "      mkdir -p /etc/kubernetes/etcd-ca"
echo "      cd /etc/kubernetes/etcd-ca"
echo "      openssl genrsa -out ca-key.pem 2048"
echo "      openssl req -new -x509 -days 3650 -key ca-key.pem -out ca-cert.pem"
echo ""
echo "   b. Update the etcd pod manifest (/etc/kubernetes/manifests/etcd.yaml):"
echo "      - Change --trusted-ca-file to point to the new CA cert"
echo "      - Update --client-cert-file and --client-key-file if needed"
echo "      - Update peer certificate references"
echo ""
echo "   c. Recreate the etcd pod (Kubernetes will handle this automatically)"
echo ""
echo "3. Verify the configuration:"
echo "   - Check that etcd and kube-apiserver use different CA files"
echo "   - Verify etcd is still running and healthy"
echo ""
echo "[PASS] Manual remediation guidance provided"
echo "[INFO] Please complete the manual steps above"
exit 0
