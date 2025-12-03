#!/bin/bash
# Kubelet Status Diagnostic - Check before recovery
# Shows current state and helps decide if recovery is needed

set -u

KUBELET_CONFIG="${1:-/var/lib/kubelet/config.yaml}"

echo "=========================================="
echo "Kubelet Status Diagnostic"
echo "=========================================="
echo "Timestamp: $(date)"
echo "Config: $KUBELET_CONFIG"
echo ""

# Check if config exists
if [ ! -f "$KUBELET_CONFIG" ]; then
    echo "[CRITICAL] Config file NOT FOUND: $KUBELET_CONFIG"
    echo "Action: Create it using worker_recovery.py"
    exit 1
fi

# Show file info
echo "[1] Config File Status:"
ls -lh "$KUBELET_CONFIG"
wc -l "$KUBELET_CONFIG"
echo ""

# Check if JSON/YAML valid
echo "[2] Config Syntax Check:"
if python3 -m json.tool "$KUBELET_CONFIG" > /dev/null 2>&1; then
    echo "✓ Config is valid JSON (and YAML)"
else
    echo "✗ Config is INVALID - JSON syntax error"
    echo "  First 20 lines:"
    head -20 "$KUBELET_CONFIG" | sed 's/^/    /'
    exit 1
fi
echo ""

# Check critical keys
echo "[3] CIS Required Keys:"
python3 << 'PYEOF'
import json
import sys

try:
    with open(sys.argv[1]) as f:
        config = json.load(f)
    
    keys = [
        ("authentication", "anonymous", "enabled"),
        ("authentication", "webhook", "enabled"),
        ("authentication", "x509", "clientCAFile"),
        ("authorization", "mode"),
        ("readOnlyPort",),
        ("makeIPTablesUtilChains",),
        ("rotateCertificates",),
        ("rotateServerCertificates",),
        ("podPidsLimit",),
        ("seccompDefault",),
    ]
    
    for key_path in keys:
        obj = config
        found = True
        for key in key_path:
            if isinstance(obj, dict) and key in obj:
                obj = obj[key]
            else:
                found = False
                break
        
        status = "✓" if found else "✗"
        key_str = ".".join(str(k) for k in key_path)
        print(f"  {status} {key_str}: {obj if found else 'MISSING'}")

except json.JSONDecodeError as e:
    print(f"  ✗ JSON Parse Error: {e}")
    sys.exit(1)
except Exception as e:
    print(f"  ✗ Error: {e}")
    sys.exit(1)
PYEOF

echo ""

# Check kubelet service
echo "[4] Kubelet Service Status:"
if systemctl is-active --quiet kubelet; then
    echo "✓ kubelet is RUNNING"
    systemctl status kubelet --no-pager | head -5
else
    echo "✗ kubelet is STOPPED or FAILED"
    systemctl status kubelet --no-pager | head -10 || true
fi
echo ""

# Show recent errors
echo "[5] Recent Kubelet Errors (last 10):"
journalctl -u kubelet -n 10 --no-pager 2>/dev/null | grep -i "error\|fail\|invalid\|denied" || echo "  (no errors found)"
echo ""

# Summary
echo "[6] Recovery Decision:"
if ! python3 -m json.tool "$KUBELET_CONFIG" > /dev/null 2>&1; then
    echo "  ⚠️  Config is BROKEN - RUN RECOVERY"
    echo "  Command: sudo python3 /path/to/worker_recovery.py"
elif ! systemctl is-active --quiet kubelet; then
    echo "  ⚠️  Kubelet not running - Check logs or run recovery"
    echo "  Logs: sudo journalctl -fu kubelet"
else
    echo "  ✓ System appears healthy - No recovery needed"
fi

echo ""
echo "=========================================="
