#!/bin/bash
#
# Verification Script for CIS 5.2.x PSS Audit Fixes
# This script validates that the updated audit scripts work correctly
#

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=============================================="
echo "CIS 5.2.x PSS Audit Script Verification"
echo "=============================================="
echo ""

# Check if we have kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}[ERROR] kubectl not found${NC}"
    exit 1
fi

# Check if we have jq
if ! command -v jq &> /dev/null; then
    echo -e "${RED}[ERROR] jq not found${NC}"
    exit 1
fi

# Get all namespaces and their PSS labels
echo -e "${YELLOW}[INFO] Fetching namespace PSS labels...${NC}"
echo ""

ns_json=$(kubectl get ns -o json 2>/dev/null)

# Show current configuration
echo -e "${YELLOW}[REPORT] Current PSS Label Configuration:${NC}"
echo "$ns_json" | jq -r '.items[] | select(.metadata.name != "kube-system" and .metadata.name != "kube-public" and .metadata.name != "kube-node-lease") | 
  "\(.metadata.name):
    enforce=\(.metadata.labels["pod-security.kubernetes.io/enforce"] // "NOT_SET")
    warn=\(.metadata.labels["pod-security.kubernetes.io/warn"] // "NOT_SET")
    audit=\(.metadata.labels["pod-security.kubernetes.io/audit"] // "NOT_SET")"
' || true

echo ""

# Check for namespaces missing all labels
missing_all=$(echo "$ns_json" | jq -r '.items[] | select(.metadata.name != "kube-system" and .metadata.name != "kube-public" and .metadata.name != "kube-node-lease") | select((.metadata.labels["pod-security.kubernetes.io/enforce"] == null) and (.metadata.labels["pod-security.kubernetes.io/warn"] == null) and (.metadata.labels["pod-security.kubernetes.io/audit"] == null)) | .metadata.name')

if [ -n "$missing_all" ]; then
    echo -e "${RED}[FAIL] Namespaces missing ALL PSS labels:${NC}"
    echo "$missing_all" | sed 's/^/  - /'
    echo ""
else
    echo -e "${GREEN}[PASS] No namespaces missing ALL PSS labels${NC}"
    echo ""
fi

# Check for invalid values
invalid=$(echo "$ns_json" | jq -r '.items[] | select(.metadata.name != "kube-system" and .metadata.name != "kube-public" and .metadata.name != "kube-node-lease") | 
  select(
    ((.metadata.labels["pod-security.kubernetes.io/enforce"] != null and 
      .metadata.labels["pod-security.kubernetes.io/enforce"] != "restricted" and 
      .metadata.labels["pod-security.kubernetes.io/enforce"] != "baseline")) or 
    ((.metadata.labels["pod-security.kubernetes.io/warn"] != null and 
      .metadata.labels["pod-security.kubernetes.io/warn"] != "restricted" and 
      .metadata.labels["pod-security.kubernetes.io/warn"] != "baseline")) or 
    ((.metadata.labels["pod-security.kubernetes.io/audit"] != null and 
      .metadata.labels["pod-security.kubernetes.io/audit"] != "restricted" and 
      .metadata.labels["pod-security.kubernetes.io/audit"] != "baseline"))
  ) | .metadata.name')

if [ -n "$invalid" ]; then
    echo -e "${RED}[FAIL] Namespaces with INVALID PSS label values:${NC}"
    echo "$invalid" | sed 's/^/  - /'
    echo ""
else
    echo -e "${GREEN}[PASS] All PSS labels have correct values${NC}"
    echo ""
fi

# Test one audit script
echo -e "${YELLOW}[TEST] Running sample audit script...${NC}"
echo ""

if [ -f "Level_1_Master_Node/5.2.2_audit.sh" ]; then
    if bash Level_1_Master_Node/5.2.2_audit.sh > /tmp/audit_test.log 2>&1; then
        echo -e "${GREEN}[PASS] Audit script executed successfully${NC}"
        # Show the final result
        tail -5 /tmp/audit_test.log | grep -E '\[PASS\]|\[FAIL\]' || true
    else
        echo -e "${RED}[FAIL] Audit script failed${NC}"
        tail -20 /tmp/audit_test.log
    fi
else
    echo -e "${YELLOW}[SKIP] 5.2.2_audit.sh not found - skipping test${NC}"
fi

echo ""
echo "=============================================="
echo "Verification Complete"
echo "=============================================="
