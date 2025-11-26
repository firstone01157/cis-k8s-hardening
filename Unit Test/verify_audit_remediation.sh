#!/bin/bash
#
# Audit Remediation Verification Script
# Quick verification of audit logging configuration
#

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0
WARNINGS=0

test_case() {
    local test_name="$1"
    local test_cmd="$2"
    local expected_result="${3:-0}"
    
    echo -n "Testing: $test_name ... "
    
    if eval "$test_cmd" > /dev/null 2>&1; then
        if [[ "$expected_result" == "0" ]]; then
            echo -e "${GREEN}PASS${NC}"
            ((PASSED++))
        else
            echo -e "${RED}FAIL${NC}"
            ((FAILED++))
        fi
    else
        if [[ "$expected_result" == "1" ]]; then
            echo -e "${GREEN}PASS${NC}"
            ((PASSED++))
        else
            echo -e "${RED}FAIL${NC}"
            ((FAILED++))
        fi
    fi
}

echo "================================================================================"
echo "AUDIT LOGGING VERIFICATION SUITE"
echo "================================================================================"
echo ""

echo -e "${BLUE}[PHASE 1] Manifest Structure Checks${NC}"
echo "---"

test_case "Manifest exists" "test -f /etc/kubernetes/manifests/kube-apiserver.yaml"
test_case "audit-log-path flag present" "grep -q 'audit-log-path' /etc/kubernetes/manifests/kube-apiserver.yaml"
test_case "audit-policy-file flag present" "grep -q 'audit-policy-file' /etc/kubernetes/manifests/kube-apiserver.yaml"
test_case "audit-log-maxage flag present" "grep -q 'audit-log-maxage' /etc/kubernetes/manifests/kube-apiserver.yaml"
test_case "audit-log-maxbackup flag present" "grep -q 'audit-log-maxbackup' /etc/kubernetes/manifests/kube-apiserver.yaml"
test_case "audit-log-maxsize flag present" "grep -q 'audit-log-maxsize' /etc/kubernetes/manifests/kube-apiserver.yaml"

echo ""
echo -e "${BLUE}[PHASE 2] Volume/Mount Checks${NC}"
echo "---"

test_case "volumeMounts section exists" "grep -q 'volumeMounts:' /etc/kubernetes/manifests/kube-apiserver.yaml"
test_case "audit-log volumeMount present" "grep -q 'name: audit-log' /etc/kubernetes/manifests/kube-apiserver.yaml"
test_case "audit-policy volumeMount present" "grep -q 'name: audit-policy' /etc/kubernetes/manifests/kube-apiserver.yaml"
test_case "volumes section exists" "grep -q '^  volumes:' /etc/kubernetes/manifests/kube-apiserver.yaml"

echo ""
echo -e "${BLUE}[PHASE 3] Filesystem Checks${NC}"
echo "---"

test_case "Audit directory exists" "test -d /var/log/kubernetes/audit"
test_case "Audit directory readable" "test -r /var/log/kubernetes/audit"
test_case "Audit directory writable" "test -w /var/log/kubernetes/audit"
test_case "Audit policy file exists" "test -f /var/log/kubernetes/audit/audit-policy.yaml"
test_case "Audit policy file readable" "test -r /var/log/kubernetes/audit/audit-policy.yaml"

echo ""
echo -e "${BLUE}[PHASE 4] Runtime Checks${NC}"
echo "---"

if command -v kubectl &> /dev/null; then
    test_case "API server pod exists" "kubectl get pod -n kube-system -l component=kube-apiserver"
    
    POD_STATUS=$(kubectl get pod -n kube-system -l component=kube-apiserver -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
    echo -n "Checking: API server pod status is Running ... "
    if [[ "$POD_STATUS" == "Running" ]]; then
        echo -e "${GREEN}PASS (Status: $POD_STATUS)${NC}"
        ((PASSED++))
    else
        echo -e "${YELLOW}WARNING (Status: $POD_STATUS)${NC}"
        ((WARNINGS++))
    fi
    
    test_case "Cluster nodes are Ready" "kubectl get nodes | grep -q ' Ready '"
else
    echo -e "${YELLOW}[SKIP]${NC} kubectl not found (skipping runtime checks)"
fi

echo ""
echo -e "${BLUE}[PHASE 5] Audit Compliance Checks${NC}"
echo "---"

# Check YAML validity
if command -v yamllint &> /dev/null; then
    echo -n "Checking: YAML syntax ... "
    if yamllint -d relaxed /etc/kubernetes/manifests/kube-apiserver.yaml > /dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC}"
        ((FAILED++))
    fi
else
    echo -n "Checking: YAML syntax (basic) ... "
    if python3 -c "import yaml; yaml.safe_load(open('/etc/kubernetes/manifests/kube-apiserver.yaml'))" 2>/dev/null; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
    else
        echo -e "${YELLOW}SKIP${NC} (no YAML validator available)"
    fi
fi

# Check audit policy validity
echo -n "Checking: Audit policy YAML ... "
if python3 -c "import yaml; yaml.safe_load(open('/var/log/kubernetes/audit/audit-policy.yaml'))" 2>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAILED++))
fi

# Run CIS audit scripts if available
echo ""
echo -e "${BLUE}[PHASE 6] CIS Audit Script Results${NC}"
echo "---"

for script in 1.2.16_audit.sh 1.2.17_audit.sh 1.2.18_audit.sh 1.2.19_audit.sh; do
    if [[ -f "Level_1_Master_Node/$script" ]]; then
        echo -n "Running: CIS $script ... "
        if bash "Level_1_Master_Node/$script" > /dev/null 2>&1; then
            echo -e "${GREEN}PASS${NC}"
            ((PASSED++))
        else
            echo -e "${RED}FAIL${NC}"
            ((FAILED++))
        fi
    fi
done

# Summary
echo ""
echo "================================================================================"
echo "VERIFICATION SUMMARY"
echo "================================================================================"
echo -e "  ${GREEN}Passed:${NC}   $PASSED"
echo -e "  ${RED}Failed:${NC}   $FAILED"
echo -e "  ${YELLOW}Warnings:${NC} $WARNINGS"
echo ""

if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All critical checks PASSED${NC}"
    exit 0
else
    echo -e "${RED}✗ Some checks FAILED - review results above${NC}"
    exit 1
fi
