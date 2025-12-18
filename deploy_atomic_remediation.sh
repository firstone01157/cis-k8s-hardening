#!/bin/bash
# Deployment and Setup Guide for Atomic Remediation System
# ============================================================

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     Atomic Remediation System - Deployment & Setup             ║"
echo "║     Prevents Remediation Loops and Cluster Crashes             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo

# ============================================================
# STEP 1: Check Prerequisites
# ============================================================
echo "[STEP 1] Checking prerequisites..."

check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "❌ $1 is not installed. Please install it first."
        exit 1
    fi
    echo "✅ $1 is installed"
}

check_command "python3"
check_command "pip3"
check_command "kubectl"
check_command "bash"

echo

# ============================================================
# STEP 2: Create Required Directories
# ============================================================
echo "[STEP 2] Creating required directories..."

BACKUP_DIR="/var/backups/cis-remediation"
LOG_DIR="/var/log/cis-remediation"

mkdir -p "$BACKUP_DIR"
mkdir -p "$LOG_DIR"

echo "✅ Created $BACKUP_DIR"
echo "✅ Created $LOG_DIR"

# Set proper permissions
chmod 700 "$BACKUP_DIR"
chmod 755 "$LOG_DIR"

echo "✅ Set directory permissions"
echo

# ============================================================
# STEP 3: Install Python Dependencies
# ============================================================
echo "[STEP 3] Installing Python dependencies..."

REQUIREMENTS="PyYAML>=5.4
requests>=2.25.0
urllib3>=1.26.0"

echo "$REQUIREMENTS" > /tmp/requirements.txt

pip3 install -q -r /tmp/requirements.txt 2>&1 | grep -v "already satisfied" || true

echo "✅ Dependencies installed:"
python3 -c "import yaml; import requests; import urllib3; print('  - PyYAML')"
python3 -c "import yaml; import requests; import urllib3; print('  - requests')"
python3 -c "import yaml; import requests; import urllib3; print('  - urllib3')"

echo

# ============================================================
# STEP 4: Copy Atomic Remediation Files
# ============================================================
echo "[STEP 4] Installing atomic remediation modules..."

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$PROJECT_ROOT/atomic_remediation.py" ]; then
    echo "✅ atomic_remediation.py found"
else
    echo "❌ atomic_remediation.py not found at $PROJECT_ROOT"
    exit 1
fi

# Make it executable
chmod +x "$PROJECT_ROOT/atomic_remediation.py"

echo

# ============================================================
# STEP 5: Set Up Logging
# ============================================================
echo "[STEP 5] Setting up logging..."

LOG_FILE="$LOG_DIR/remediation.log"
touch "$LOG_FILE"
chmod 666 "$LOG_FILE"

echo "✅ Logging configured at: $LOG_FILE"
echo

# ============================================================
# STEP 6: Test Atomic Manager Functionality
# ============================================================
echo "[STEP 6] Testing atomic remediation functionality..."

python3 << 'PYTHON_TEST'
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    from atomic_remediation import AtomicRemediationManager
    manager = AtomicRemediationManager(backup_dir="/tmp/test-backup")
    print("✅ AtomicRemediationManager imported successfully")
    print("✅ Backup directory initialized: /tmp/test-backup")
    
    # Test backup creation
    test_file = "/tmp/test_atomic.txt"
    with open(test_file, 'w') as f:
        f.write("test content")
    
    success, backup_path = manager.create_backup(test_file)
    if success:
        print(f"✅ Test backup created: {backup_path}")
    else:
        print("❌ Test backup creation failed")
        sys.exit(1)
    
    # Clean up
    os.remove(test_file)
    os.remove(backup_path)
    os.rmdir(os.path.dirname(backup_path))
    
except Exception as e:
    print(f"❌ Test failed: {e}")
    sys.exit(1)
PYTHON_TEST

echo

# ============================================================
# STEP 7: Verify Kubernetes Access
# ============================================================
echo "[STEP 7] Verifying Kubernetes cluster access..."

if kubectl cluster-info &> /dev/null; then
    CLUSTER_NAME=$(kubectl config current-context)
    echo "✅ Connected to cluster: $CLUSTER_NAME"
else
    echo "⚠️  Could not verify cluster connection"
    echo "    Make sure KUBECONFIG is set properly:"
    echo "    export KUBECONFIG=/etc/kubernetes/admin.conf"
fi

echo

# ============================================================
# STEP 8: Display Configuration Summary
# ============================================================
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              DEPLOYMENT COMPLETE                              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo
echo "Configuration Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Backup Directory:    $BACKUP_DIR"
echo "  Log Directory:       $LOG_DIR"
echo "  Log File:            $LOG_FILE"
echo "  Python Version:      $(python3 --version)"
echo "  Project Root:        $PROJECT_ROOT"
echo

echo "Required Environment Variables:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  export KUBECONFIG=/etc/kubernetes/admin.conf"
echo "  export LOG_DIR=$LOG_DIR"
echo

echo "Next Steps:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  1. Test the system:"
echo "     python3 test_atomic_remediation.py"
echo
echo "  2. Run remediation with atomic writes:"
echo "     python3 cis_k8s_unified.py --remediate"
echo
echo "  3. Monitor logs in real-time:"
echo "     tail -f $LOG_FILE"
echo
echo "  4. Check backups:"
echo "     ls -lah $BACKUP_DIR"
echo
echo "  5. Review integration guide:"
echo "     cat ATOMIC_REMEDIATION_INTEGRATION.md"
echo

echo "Atomic Remediation Features:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Atomic file writes (no partial files)"
echo "  ✅ Automatic backup before changes"
echo "  ✅ Health check barrier (wait for cluster)"
echo "  ✅ Auto-rollback on failure"
echo "  ✅ Comprehensive logging"
echo "  ✅ Remediation verification (audit checks)"
echo

echo "Troubleshooting:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Issue: 'Module atomic_remediation not found'"
echo "  Fix:   Make sure atomic_remediation.py is in the project root"
echo
echo "  Issue: 'Permission denied' when accessing KUBECONFIG"
echo "  Fix:   chmod 600 /etc/kubernetes/admin.conf"
echo
echo "  Issue: 'Health check timeout' during remediation"
echo "  Fix:   Check if API server is actually restarting:"
echo "         kubectl get pods -n kube-system | grep apiserver"
echo
echo "  Issue: Backups accumulating"
echo "  Fix:   Implement cleanup: ls -t $BACKUP_DIR | tail -n +6 | xargs -r rm"
echo
