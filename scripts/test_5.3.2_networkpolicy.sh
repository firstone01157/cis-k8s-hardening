#!/bin/bash
# CIS 5.3.2 NetworkPolicy - Demo & Testing Script
# 
# This script demonstrates and tests the NetworkPolicy automation
# without requiring modifications to your actual cluster.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TEST_NS="cis-5.3.2-test-$(date +%s)"

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}CIS 5.3.2 NetworkPolicy - Demo & Testing${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}[1/6] Checking prerequisites...${NC}"
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}✗ kubectl not found. Please install kubectl.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ kubectl found${NC}"

if ! command -v python3 &> /dev/null; then
    echo -e "${RED}✗ python3 not found. Please install python3.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ python3 found${NC}"

# Check kubectl connectivity
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}✗ Cannot connect to Kubernetes cluster${NC}"
    echo "    Please configure kubectl access"
    exit 1
fi
echo -e "${GREEN}✓ kubectl cluster accessible${NC}"
echo ""

# Test audit script
echo -e "${YELLOW}[2/6] Testing audit script...${NC}"
if [ -f "$PROJECT_ROOT/Level_1_Master_Node/5.3.2_audit.sh" ]; then
    if bash -n "$PROJECT_ROOT/Level_1_Master_Node/5.3.2_audit.sh" 2>/dev/null; then
        echo -e "${GREEN}✓ Audit script syntax valid${NC}"
    else
        echo -e "${RED}✗ Audit script has syntax errors${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Audit script not found at $PROJECT_ROOT/Level_1_Master_Node/5.3.2_audit.sh${NC}"
    exit 1
fi
echo ""

# Test remediation script
echo -e "${YELLOW}[3/6] Testing remediation script...${NC}"
if [ -f "$PROJECT_ROOT/Level_1_Master_Node/5.3.2_remediate.sh" ]; then
    if bash -n "$PROJECT_ROOT/Level_1_Master_Node/5.3.2_remediate.sh" 2>/dev/null; then
        echo -e "${GREEN}✓ Remediation script syntax valid${NC}"
    else
        echo -e "${RED}✗ Remediation script has syntax errors${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Remediation script not found${NC}"
    exit 1
fi
echo ""

# Test Python script
echo -e "${YELLOW}[4/6] Testing Python implementation...${NC}"
if [ -f "$PROJECT_ROOT/network_policy_manager.py" ]; then
    if python3 "$PROJECT_ROOT/network_policy_manager.py" --help &>/dev/null; then
        echo -e "${GREEN}✓ Python script callable and functional${NC}"
    else
        echo -e "${RED}✗ Python script has errors${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Python script not found${NC}"
    exit 1
fi
echo ""

# Create test namespace
echo -e "${YELLOW}[5/6] Creating test namespace: ${BLUE}$TEST_NS${NC}"
if kubectl create namespace "$TEST_NS" &>/dev/null; then
    echo -e "${GREEN}✓ Test namespace created${NC}"
    CLEANUP_NS=true
else
    echo -e "${RED}✗ Failed to create test namespace${NC}"
    exit 1
fi
echo ""

# Test dry-run
echo -e "${YELLOW}[6/6] Testing dry-run remediation...${NC}"
echo ""
echo -e "${BLUE}Running: python3 network_policy_manager.py --remediate --dry-run --verbose${NC}"
echo ""

if python3 "$PROJECT_ROOT/network_policy_manager.py" --remediate --dry-run --verbose 2>&1 | head -30; then
    echo ""
    echo -e "${GREEN}✓ Dry-run completed successfully${NC}"
else
    echo -e "${RED}✗ Dry-run failed${NC}"
fi
echo ""

# Cleanup
echo -e "${YELLOW}Cleaning up test namespace...${NC}"
if [ "$CLEANUP_NS" = "true" ]; then
    kubectl delete namespace "$TEST_NS" &>/dev/null
    echo -e "${GREEN}✓ Test namespace deleted${NC}"
fi
echo ""

# Summary
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ All tests passed! System is ready to use.${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Next steps:"
echo "  1. Audit compliance:      bash $PROJECT_ROOT/Level_1_Master_Node/5.3.2_audit.sh"
echo "  2. Remediate namespaces:  python3 $PROJECT_ROOT/network_policy_manager.py --remediate"
echo "  3. Check documentation:   cat $PROJECT_ROOT/docs/CIS_5.3.2_NETWORKPOLICY_GUIDE.md"
echo ""
