#!/bin/bash
set -xe

# CIS Benchmark: 3.2.2
# Title: Ensure that the audit policy covers key security concerns (AUTOMATED)
# Level: Level 2 - Master Node
# Description: Verify that the kube-apiserver manifest contains required audit flags
# Strategy: Check static manifest file for audit configuration flags

SCRIPT_NAME="3.2.2_audit.sh"
APISERVER_MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"

echo "[INFO] Starting CIS Benchmark check: 3.2.2"
echo "[INFO] Checking for audit configuration in kube-apiserver manifest..."

# Verify manifest file exists
if [ ! -f "$APISERVER_MANIFEST" ]; then
    echo "[FAIL] kube-apiserver manifest not found: $APISERVER_MANIFEST"
    exit 1
fi

echo "[DEBUG] Manifest file: $APISERVER_MANIFEST"

# Check for required audit flags in the manifest
echo "[INFO] Checking for required audit flags..."

REQUIRED_FLAGS=(
    "--audit-policy-file"
    "--audit-log-path"
    "--audit-log-maxage"
)

all_flags_present=true
found_flags=()
missing_flags=()

for flag in "${REQUIRED_FLAGS[@]}"; do
    if grep -F -q -- "$flag" "$APISERVER_MANIFEST"; then
        echo "[INFO] Found: $flag"
        found_flags+=("$flag")
    else
        echo "[FAIL] Missing: $flag"
        missing_flags+=("$flag")
        all_flags_present=false
    fi
done

# Final report
echo ""
echo "========================================================"
echo "[INFO] CIS 3.2.2 Audit Results:"
echo "========================================================"

if [ "$all_flags_present" = true ]; then
    echo "[INFO] Found all required audit flags:"
    for flag in "${found_flags[@]}"; do
        echo "  ✓ $flag"
    done
    echo ""
    echo "[INFO] Check Passed"
    exit 0
else
    echo "[FAIL] Missing required audit flags:"
    for flag in "${missing_flags[@]}"; do
        echo "  ✗ $flag"
    done
    echo ""
    echo "[INFO] Found flags:"
    for flag in "${found_flags[@]}"; do
        echo "  ✓ $flag"
    done
    echo ""
    echo "[FAIL] CIS 3.2.2 check failed"
    exit 1
fi
