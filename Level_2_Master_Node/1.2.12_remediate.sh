#!/bin/bash
set -xe

# CIS Benchmark: 1.2.12
# Title: Ensure that the admission control plugin ServiceAccount is set (Automated)
# Level: Level 2 - Master Node
# Remediation: Remove ServiceAccount from --disable-admission-plugins if it exists

SCRIPT_NAME="1.2.12_remediate.sh"
echo "[INFO] Starting CIS Benchmark remediation: 1.2.12"

remediation_success=false
MANIFEST_FILE="/etc/kubernetes/manifests/kube-apiserver.yaml"

# Check if manifest file exists
if [ ! -f "$MANIFEST_FILE" ]; then
    echo "[FAIL] Manifest file not found: $MANIFEST_FILE"
    exit 1
fi

echo "[INFO] Backing up manifest file..."
BACKUP_FILE="${MANIFEST_FILE}.bak_$(date +%s)"
cp "$MANIFEST_FILE" "$BACKUP_FILE"
echo "[INFO] Backup created: $BACKUP_FILE"

# Check if --disable-admission-plugins is set
echo "[INFO] Checking current --disable-admission-plugins setting..."
if grep -F -q -- "--disable-admission-plugins" "$MANIFEST_FILE"; then
    echo "[INFO] --disable-admission-plugins is currently set in manifest"
    
    # Check if ServiceAccount is in the disabled plugins
    if grep -F -q -- "ServiceAccount" "$MANIFEST_FILE" && grep -F -q -- "--disable-admission-plugins" "$MANIFEST_FILE"; then
        echo "[INFO] Applying fix: Removing ServiceAccount from --disable-admission-plugins"
        
        # Use sed to remove ServiceAccount from the --disable-admission-plugins line
        # This handles cases like: --disable-admission-plugins=Plugin1,ServiceAccount,Plugin2
        sed -i 's/,ServiceAccount//g; s/ServiceAccount,//g' "$MANIFEST_FILE"
        
        echo "[INFO] Fix applied. Verifying..."
        if grep -F -q "ServiceAccount" "$MANIFEST_FILE"; then
            echo "[FAIL] ServiceAccount still present in manifest after remediation"
            cp "$BACKUP_FILE" "$MANIFEST_FILE"
            echo "[INFO] Restored from backup"
            exit 1
        else
            echo "[PASS] Successfully removed ServiceAccount from --disable-admission-plugins"
            remediation_success=true
        fi
    else
        echo "[PASS] ServiceAccount not in --disable-admission-plugins (no fix needed)"
        remediation_success=true
    fi
else
    echo "[PASS] --disable-admission-plugins not set (ServiceAccount is enabled by default - no fix needed)"
    remediation_success=true
fi

# Final report
echo ""
echo "==============================================="
if [ "$remediation_success" = true ]; then
    echo "[PASS] CIS 1.2.12: Remediation completed successfully"
    echo "[INFO] Please restart kube-apiserver for changes to take effect"
    exit 0
else
    echo "[FAIL] CIS 1.2.12: Remediation failed"
    exit 1
fi
