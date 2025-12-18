#!/bin/bash
set -euo pipefail

# CIS Benchmark: 4.2.12
# Title: Ensure that the --tls-cipher-suites argument is set to strong values
# Level: Level 1 - Worker Node
# Remediation Script (Environment Variable Delegation)

echo "[INFO] Remediating CIS 4.2.12: tls-cipher-suites"

# 1. Export CIS setting as environment variable for harden_kubelet.py
# Strong TLS cipher suites as per CIS Benchmark
export CONFIG_TLS_CIPHER_SUITES="TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384"

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
	echo "[FIXED] CIS 4.2.12: Applied tls-cipher-suites via harden_kubelet.py"
	exit 0
else
	echo "[ERROR] harden_kubelet.py failed"
	exit 1
fi
