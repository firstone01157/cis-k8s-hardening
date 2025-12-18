#!/bin/bash
set -euo pipefail

# CIS Benchmark: 4.2.7
# Title: Ensure that the --event-record-qps argument is set as appropriate
# Level: Level 1 - Worker Node
# Remediation Script (Environment Variable Delegation)

echo "[INFO] Remediating CIS 4.2.7: event-record-qps=0"

# 1. Export CIS setting as environment variable for harden_kubelet.py
export CONFIG_EVENT_RECORD_QPS="0"

# 2. Locate harden_kubelet.py
if [ -f "./harden_kubelet.py" ]; then
	HARDENER="./harden_kubelet.py"
elif [ -f "../harden_kubelet.py" ]; then
	HARDENER="../harden_kubelet.py"
elif [ -f "../../harden_kubelet.py" ]; then
	HARDENER="../../harden_kubelet.py"
else
	echo "[ERROR] harden_kubelet.py not found in expected locations"
	exit 1
fi

# 3. Delegate to Python hardener
echo "[INFO] Delegating to Python hardener: $HARDENER"
if python3 "$HARDENER"; then
	echo "[FIXED] CIS 4.2.7: Applied event-record-qps=0 via harden_kubelet.py"
	exit 0
else
	echo "[ERROR] harden_kubelet.py failed"
	exit 1
fi
