#!/bin/bash
set -xe

# CIS Benchmark: 3.2.2
# Title: Ensure that the audit policy covers key security concerns (AUTOMATED)
# Level: Level 2 - Master Node
# Remediation: Automated audit policy creation and kube-apiserver configuration

SCRIPT_NAME="3.2.2_remediate.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_HELPER="${SCRIPT_DIR}/../harden_apiserver_audit.py"

echo "[INFO] Starting CIS Benchmark remediation: 3.2.2"
echo "[INFO] This is AUTOMATED remediation using Python helper"

# Verify running as root
if [ "$(id -u)" != "0" ]; then
    echo "[FAIL] This script must be run as root"
    exit 1
fi

# Verify Python helper exists
if [ ! -f "$PYTHON_HELPER" ]; then
    echo "[FAIL] Python helper not found: $PYTHON_HELPER"
    echo "[INFO] Please ensure harden_apiserver_audit.py is in the parent directory"
    exit 1
fi

echo "[DEBUG] Python helper: $PYTHON_HELPER"

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo "[FAIL] Python 3 is not installed"
    echo "[INFO] Install Python 3 and required packages (PyYAML)"
    exit 1
fi

echo "[DEBUG] Python 3 found: $(python3 --version)"

# Check if PyYAML is available
if ! python3 -c "import yaml" 2>/dev/null; then
    echo "[FAIL] PyYAML package not found"
    echo "[INFO] Install with: pip3 install PyYAML"
    exit 1
fi

echo "[DEBUG] PyYAML module available"

echo ""
echo "========================================================"
echo "[INFO] CIS 3.2.2: Automated Audit Policy Configuration"
echo "========================================================"
echo ""

# Call the Python helper
echo "[INFO] Executing Python automation helper..."
python3 "$PYTHON_HELPER"
HELPER_RESULT=$?

if [ $HELPER_RESULT -ne 0 ]; then
    echo ""
    echo "[FAIL] Automation helper failed with exit code: $HELPER_RESULT"
    echo "[INFO] Manual verification may be needed"
    echo "[INFO] Run: python3 $PYTHON_HELPER for details"
    exit 1
fi

echo ""
echo "========================================================"
echo "[INFO] Audit policy automation completed"
echo "========================================================"
echo ""
echo "[INFO] Summary of changes:"
echo "  - Audit policy created: /etc/kubernetes/audit-policy.yaml"
echo "  - Audit log directory: /var/log/kubernetes/audit/"
echo "  - API Server manifest updated: /etc/kubernetes/manifests/kube-apiserver.yaml"
echo "  - Backups created with timestamp suffix"
echo ""
echo "[INFO] Next steps:"
echo "  1. Verify kube-apiserver restarted:"
echo "     kubectl get pods -n kube-system -l component=kube-apiserver"
echo "  2. Check audit logs:"
echo "     tail -f /var/log/kubernetes/audit/audit.log"
echo "  3. Run the audit script to verify:"
echo "     bash 3.2.2_audit.sh"
echo ""
echo "[PASS] CIS 3.2.2 automated remediation completed successfully"
exit 0
