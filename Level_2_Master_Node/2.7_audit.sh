#!/bin/bash
set -xe

# CIS Benchmark: 2.7
# Title: Ensure that a unique Certificate Authority is used for etcd (Manual)
# Level: Level 2 - Master Node
# Description: Verify that etcd uses a unique CA that differs from the Kubernetes cluster CA

SCRIPT_NAME="2.7_audit.sh"
echo "[INFO] Starting CIS Benchmark check: 2.7"
echo "[INFO] This is a MANUAL CHECK - requires human review and verification"

# Initialize variables
audit_passed=true
failure_reasons=()
details=()

# Get etcd process info
echo "[INFO] Checking etcd process..."
if ps -ef | grep -v grep | grep -q "etcd"; then
    echo "[INFO] etcd process is running"
    
    # Extract --trusted-ca-file from etcd
    echo "[INFO] Extracting etcd --trusted-ca-file..."
    etcd_ca=$(ps -ef | grep -v grep | grep "etcd" | tr ' ' '\n' | grep -A1 "^--trusted-ca-file$" | tail -1 || echo "NOT_FOUND")
    echo "[DEBUG] etcd CA file: $etcd_ca"
    details+=("etcd --trusted-ca-file: $etcd_ca")
    
    # Extract --client-ca-file from kube-apiserver
    echo "[INFO] Extracting kube-apiserver --client-ca-file..."
    if ps -ef | grep -v grep | grep -q "kube-apiserver"; then
        apiserver_ca=$(ps -ef | grep -v grep | grep "kube-apiserver" | tr ' ' '\n' | grep -A1 "^--client-ca-file$" | tail -1 || echo "NOT_FOUND")
        echo "[DEBUG] kube-apiserver CA file: $apiserver_ca"
        details+=("kube-apiserver --client-ca-file: $apiserver_ca")
        
        # Compare the files
        if [ "$etcd_ca" != "NOT_FOUND" ] && [ "$apiserver_ca" != "NOT_FOUND" ]; then
            if [ "$etcd_ca" = "$apiserver_ca" ]; then
                echo "[WARN] WARNING: etcd and kube-apiserver are using the SAME CA file"
                failure_reasons+=("etcd and kube-apiserver share the same CA file (should be unique)")
                audit_passed=false
            else
                echo "[PASS] etcd and kube-apiserver use DIFFERENT CA files"
            fi
        else
            echo "[INFO] Unable to fully extract CA file paths - MANUAL VERIFICATION REQUIRED"
            failure_reasons+=("Could not extract CA file paths - manual verification needed")
            audit_passed=false
        fi
    else
        echo "[FAIL] kube-apiserver process not found"
        failure_reasons+=("kube-apiserver process not running")
        audit_passed=false
    fi
else
    echo "[FAIL] etcd process is not running"
    failure_reasons+=("etcd process not running")
    audit_passed=false
fi

# Final report
echo ""
echo "==============================================="
echo "[INFO] CIS 2.7 Audit Results:"
echo "Details:"
for detail in "${details[@]}"; do
    echo "  - $detail"
done

if [ "$audit_passed" = true ]; then
    echo "[PASS] CIS 2.7: Unique CA for etcd appears to be configured"
    echo "[INFO] For production environments, manually verify these files are indeed different:"
    echo "       - Review the CA certificates to ensure they contain different public keys"
    echo "       - Use: openssl x509 -in <file> -noout -pubkey"
    exit 0
else
    echo "[FAIL] CIS 2.7: Unique CA for etcd may NOT be configured"
    echo "Reasons:"
    for reason in "${failure_reasons[@]}"; do
        echo "  - $reason"
    done
    echo "[INFO] Manual verification steps:"
    echo "  1. Run: ps -ef | grep etcd | grep -o -- '--trusted-ca-file=[^ ]*'"
    echo "  2. Run: ps -ef | grep kube-apiserver | grep -o -- '--client-ca-file=[^ ]*'"
    echo "  3. Compare the certificate files to ensure they are different"
    exit 1
fi
