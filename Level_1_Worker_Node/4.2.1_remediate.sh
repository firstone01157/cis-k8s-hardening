#!/bin/bash
# CIS Benchmark: 4.2.1
# Title: Ensure that the --anonymous-auth argument is set to false
# Level: Level 1 - Worker Node
# Remediation Script (Wrapper for harden_kubelet.py)

set -euo pipefail

# 1. Determine the absolute path to the python script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARDENER_SCRIPT=""

if [ -f "$SCRIPT_DIR/../../harden_kubelet.py" ]; then
    HARDENER_SCRIPT="$SCRIPT_DIR/../../harden_kubelet.py"
elif [ -f "$SCRIPT_DIR/../harden_kubelet.py" ]; then
    HARDENER_SCRIPT="$SCRIPT_DIR/../harden_kubelet.py"
elif [ -f "/root/cis-k8s-hardening/harden_kubelet.py" ]; then
    HARDENER_SCRIPT="/root/cis-k8s-hardening/harden_kubelet.py"
else
    echo "[ERROR] harden_kubelet.py not found!"
    exit 1
fi

echo "[INFO] Remediating 4.2.1: Delegating to $HARDENER_SCRIPT"

# 2. Export the specific variable for THIS check
if [ ! -z "${CONFIG_REQUIRED_VALUE:-}" ]; then
    SAFE_VAL=$(echo "$CONFIG_REQUIRED_VALUE" | tr -d '"')
    export CONFIG_ANONYMOUS_AUTH="$SAFE_VAL"
else
    export CONFIG_ANONYMOUS_AUTH="false"
fi

# 3. Execute the python hardener
python3 "$HARDENER_SCRIPT"
exit $?

