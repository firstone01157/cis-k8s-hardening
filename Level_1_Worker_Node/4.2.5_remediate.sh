#!/bin/bash
set -euo pipefail

# CIS Benchmark: 4.2.5
# Title: Ensure that the --streaming-connection-idle-timeout argument is set to 4h or higher
# Level: Level 1 - Worker Node
# Remediation Script (Environment Variable Delegation)

echo "[INFO] Remediating CIS 4.2.5: streaming-connection-idle-timeout=4h0m0s"

# 1. Export CIS setting as environment variable for harden_kubelet.py
export CONFIG_STREAMING_TIMEOUT="4h0m0s"

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
	echo "[FIXED] CIS 4.2.5: Applied streaming-connection-idle-timeout via harden_kubelet.py"
	exit 0
else
	echo "[ERROR] harden_kubelet.py failed"
	exit 1
fi
