#!/bin/bash
# CIS Benchmark: 4.2.12
# Title: Ensure that the Kubelet only makes use of Strong Cryptographic Ciphers (Manual)
# Level: • Level 1 - Worker Node

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/kubelet_helpers.sh"

audit_rule() {
	echo "[INFO] Starting check for 4.2.12..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# 1. Detect Config File
	echo "[CMD] Executing: config_path=$(kubelet_config_path)"
	config_path=$(kubelet_config_path)

	# 2. Priority 1: Check Flag
	echo "[CMD] Executing: if ps -ef | grep kubelet | grep -v grep | grep -E -q \"\\s--tls-cipher-suites(=|\\s|$)\"; then"
	if ps -ef | grep kubelet | grep -v grep | grep -E -q "\s--tls-cipher-suites(=|\s|$)"; then
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: --tls-cipher-suites is set (Flag)")
	
	# 3. Priority 2: Check Config File
	elif [ -f "$config_path" ]; then
		echo "[CMD] Executing: if grep -E -q \"tlsCipherSuites:\" \"$config_path\"; then"
		if grep -E -q "tlsCipherSuites:" "$config_path"; then
			echo "[INFO] Check Passed"
			a_output+=(" - Check Passed: tlsCipherSuites is set in $config_path")
		else
			echo "[INFO] Check Failed"
			a_output2+=(" - Check Failed: tlsCipherSuites is NOT set in $config_path (or missing)")
			echo "[FAIL_REASON] Check Failed: tlsCipherSuites is NOT set in $config_path (or missing)"
			echo "[FIX_HINT] Run remediation script: 4.2.12_remediate.sh"
		fi
	
	# 4. Priority 3: Default
	else
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: --tls-cipher-suites not set and config file not found (Default: missing/insecure)")
		echo "[FAIL_REASON] Check Failed: --tls-cipher-suites not set and config file not found (Default: missing/insecure)"
		echo "[FIX_HINT] Run remediation script: 4.2.12_remediate.sh"
	fi

	if [ "${#a_output2[@]}" -le 0 ]; then
		printf '%s\n' "" "- Audit Result:" "  [+] PASS" "${a_output[@]}"
		return 0
	else
		printf '%s\n' "" "- Audit Result:" "  [-] FAIL" " - Reason(s) for audit failure:" "${a_output2[@]}"
		[ "${#a_output[@]}" -gt 0 ] && printf '%s\n' "- Correctly set:" "${a_output[@]}"
		return 1
	fi
}

audit_rule
exit $?
