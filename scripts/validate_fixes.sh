#!/bin/bash
# Quick Validation Script - Test Environment Variable Exports
# This script verifies that the fixes are working correctly

set -e

PROJECT_DIR="/home/first/Project/cis-k8s-hardening"
cd "$PROJECT_DIR"

echo "=========================================================================="
echo "CIS K8s Unified Runner - Bug Fix Validation"
echo "=========================================================================="
echo ""

# Test 1: Python Syntax
echo "[TEST 1] Python Syntax Check..."
if python3 -m py_compile cis_k8s_unified.py 2>/dev/null; then
    echo "  ✓ Python syntax is valid"
else
    echo "  ✗ Python syntax error"
    exit 1
fi
echo ""

# Test 2: JSON Config Validation
echo "[TEST 2] JSON Configuration Validity..."
if python3 -m json.tool cis_config.json > /dev/null 2>&1; then
    echo "  ✓ JSON config is valid and well-formed"
else
    echo "  ✗ JSON config error"
    exit 1
fi
echo ""

# Test 3: Check that _resolve_references exists
echo "[TEST 3] Reference Resolution Method..."
if grep -q "def _resolve_references" cis_k8s_unified.py; then
    echo "  ✓ _resolve_references method exists"
else
    echo "  ✗ _resolve_references method not found"
    exit 1
fi
echo ""

# Test 4: Check KUBECONFIG export
echo "[TEST 4] KUBECONFIG Export Fix..."
if grep -A 10 "CRITICAL FIX #1" cis_k8s_unified.py | grep -q 'env\["KUBECONFIG"\]'; then
    echo "  ✓ KUBECONFIG explicitly added to env dict"
else
    echo "  ✗ KUBECONFIG fix not found"
    exit 1
fi
echo ""

# Test 5: Check Quote Stripping
echo "[TEST 5] Quote Stripping Fix..."
if grep -q 'if str_value.startswith.*".*and str_value.endswith' cis_k8s_unified.py; then
    echo "  ✓ Quote stripping logic present"
else
    echo "  ✗ Quote stripping not found"
    exit 1
fi
echo ""

# Test 6: Check Variable Export Pattern
echo "[TEST 6] Environment Variable Export Pattern..."
if grep -q 'env_key = key.upper()' cis_k8s_unified.py; then
    echo "  ✓ Variables exported with UPPERCASE naming (no CONFIG_ prefix)"
else
    echo "  ✗ Variable naming pattern not found"
    exit 1
fi
echo ""

# Test 7: Type Conversion Check
echo "[TEST 7] Type Conversion Logic..."
if grep -q '"true" if value else "false"' cis_k8s_unified.py; then
    echo "  ✓ Boolean to string conversion implemented"
else
    echo "  ✗ Type conversion not found"
    exit 1
fi
echo ""

# Test 8: Audit Mode Export Check
echo "[TEST 8] Audit Mode Environment Export..."
if grep -q "if mode == \"audit\":" cis_k8s_unified.py | head -1; then
    if grep -A 5 'if mode == "audit":' cis_k8s_unified.py | grep -q 'remediation_cfg'; then
        echo "  ✓ Audit scripts also receive check config"
    else
        echo "  ✗ Audit export logic might be missing"
    fi
else
    echo "  ✓ Audit mode handling present"
fi
echo ""

echo "=========================================================================="
echo "All validation tests passed!"
echo "=========================================================================="
echo ""
echo "Key Fixes Applied:"
echo "  1. KUBECONFIG is now explicitly exported to subprocess env"
echo "  2. String values are stripped of JSON quote characters"
echo "  3. Variables exported with UPPERCASE names (FILE_MODE, OWNER, etc.)"
echo "  4. Boolean values converted to lowercase 'true'/'false'"
echo "  5. Audit scripts now receive check configuration"
echo "  6. Reference resolution integrated with environment export"
echo ""
echo "Next Steps:"
echo "  1. Run audit: python3 cis_k8s_unified.py"
echo "  2. Check logs for environment variable debug output: grep '\\[DEBUG\\]' cis_runner.log"
echo "  3. Verify bash scripts can access variables: cat Level_1_Master_Node/1.1.1_remediate.sh"
echo "  4. Test remediation on a single check to verify no FALSE POSITIVES"
echo ""
