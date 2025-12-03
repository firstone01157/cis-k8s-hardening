#!/bin/bash
# Quick test script to verify converted audit scripts work properly
# Usage: bash test_converted_scripts.sh

set -e

echo "=========================================="
echo "Testing Converted CIS Audit Scripts"
echo "=========================================="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

passed=0
failed=0

# Test a script and capture output
test_script() {
    local script="$1"
    local name=$(basename "$script" .sh)
    
    echo -n "Testing $name ... "
    
    if bash "$script" > /tmp/test_output.txt 2>&1; then
        # Check for proper output format
        if grep -q "\[+\] PASS\|\[-\] FAIL" /tmp/test_output.txt; then
            echo -e "${GREEN}✓ PASS${NC}"
            ((passed++))
            return 0
        else
            echo -e "${RED}✗ FAIL${NC} (Invalid output format)"
            ((failed++))
            return 1
        fi
    else
        exit_code=$?
        if [ $exit_code -eq 1 ]; then
            # Script returned 1, which means FAIL - that's ok
            if grep -q "\[-\] FAIL" /tmp/test_output.txt; then
                echo -e "${GREEN}✓ FAIL (expected)${NC}"
                ((passed++))
                return 0
            fi
        fi
        echo -e "${RED}✗ ERROR${NC} (Exit code: $exit_code)"
        ((failed++))
        return 1
    fi
}

# Test RBAC checks
echo "${YELLOW}=== Section 5.1 - RBAC Checks ===${NC}"
for script in Level_1_Master_Node/5.1.{1,2,4,5,6,7,8,9,10,11,12,13}_audit.sh; do
    [ -f "$script" ] && test_script "$script"
done

echo ""
echo "${YELLOW}=== Section 5.2 - Pod Security Checks ===${NC}"
for script in Level_1_Master_Node/5.2.{1,2,3,4,5,6,8,10,11,12}_audit.sh; do
    [ -f "$script" ] && test_script "$script"
done

echo ""
echo "${YELLOW}=== Section 5.3 & 5.6 - Network & Namespace Checks ===${NC}"
for script in Level_1_Master_Node/5.{3,6}.1_audit.sh; do
    [ -f "$script" ] && test_script "$script"
done

echo ""
echo "=========================================="
echo "Test Results"
echo "=========================================="
echo -e "Passed: ${GREEN}$passed${NC}"
echo -e "Failed: ${RED}$failed${NC}"
echo "=========================================="

if [ $failed -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
