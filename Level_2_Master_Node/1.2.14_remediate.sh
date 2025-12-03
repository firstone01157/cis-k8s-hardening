#!/bin/bash
set -xe

# CIS Benchmark: 1.2.14
# Title: Ensure that the admission control plugin NodeRestriction is set (Automated)
# Level: Level 2 - Master Node
# Remediation: Add NodeRestriction to --enable-admission-plugins if not present

SCRIPT_NAME="1.2.14_remediate.sh"
echo "[INFO] Starting CIS Benchmark remediation: 1.2.14"

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

# Check if --enable-admission-plugins already contains NodeRestriction
echo "[INFO] Checking if NodeRestriction is already set..."
if grep -F -q "NodeRestriction" "$MANIFEST_FILE"; then
    echo "[PASS] NodeRestriction is already present in manifest (no fix needed)"
    remediation_success=true
elif grep -F -q -- "--enable-admission-plugins" "$MANIFEST_FILE"; then
    echo "[INFO] --enable-admission-plugins exists but NodeRestriction is missing"
    echo "[INFO] Applying fix: Appending NodeRestriction to --enable-admission-plugins"
    
    # Append NodeRestriction to the existing value
    # This handles: --enable-admission-plugins=Plugin1,Plugin2 -> --enable-admission-plugins=Plugin1,Plugin2,NodeRestriction
    sed -i 's/--enable-admission-plugins=\([^ "]*\)/&,NodeRestriction/g' "$MANIFEST_FILE"
    
    echo "[INFO] Fix applied. Verifying..."
    if grep -F -q "NodeRestriction" "$MANIFEST_FILE"; then
        echo "[PASS] Successfully added NodeRestriction to --enable-admission-plugins"
        remediation_success=true
    else
        echo "[FAIL] NodeRestriction not found in manifest after remediation"
        cp "$BACKUP_FILE" "$MANIFEST_FILE"
        echo "[INFO] Restored from backup"
        exit 1
    fi
else
    echo "[INFO] --enable-admission-plugins not found"
    echo "[INFO] Applying fix: Inserting --enable-admission-plugins=NodeRestriction"
    
    # Insert new flag (after kube-apiserver line, before other args)
    sed -i '/- kube-apiserver/a \    - --enable-admission-plugins=NodeRestriction' "$MANIFEST_FILE"
    
    echo "[INFO] Fix applied. Verifying..."
    if grep -F -q "NodeRestriction" "$MANIFEST_FILE"; then
        echo "[PASS] Successfully inserted --enable-admission-plugins=NodeRestriction"
        remediation_success=true
    else
        echo "[FAIL] NodeRestriction not found in manifest after remediation"
        cp "$BACKUP_FILE" "$MANIFEST_FILE"
        echo "[INFO] Restored from backup"
        exit 1
    fi
fi

# Final report
echo ""
echo "==============================================="
if [ "$remediation_success" = true ]; then
    echo "[PASS] CIS 1.2.14: Remediation completed successfully"
    echo "[INFO] Please restart kube-apiserver for changes to take effect"
    exit 0
else
    echo "[FAIL] CIS 1.2.14: Remediation failed"
    exit 1
fi
