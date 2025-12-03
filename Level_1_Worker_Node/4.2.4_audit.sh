#!/bin/bash
# CIS Benchmark: 4.2.4
# Title: Verify that if defined, readOnlyPort is set to 0 (Manual)
# Level: • Level 1 - Worker Node

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/kubelet_helpers.sh"

audit_rule() {
	echo "[INFO] Starting check for 4.2.4..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# 1. Detect Config File
	echo "[CMD] Executing: config_path=$(kubelet_config_path)"
	config_path=$(kubelet_config_path)

	# 2. Priority 1: Check Flag
	echo "[CMD] Executing: if ps -ef | grep kubelet | grep -v grep | grep -E -q \"\\s--read-only-port=0(\\s|$)\"; then"
	if ps -ef | grep kubelet | grep -v grep | grep -E -q "\s--read-only-port=0(\s|$)"; then
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: --read-only-port is set to 0 (Flag)")
	echo "[CMD] Executing: elif ps -ef | grep kubelet | grep -v grep | grep -E -q \"\\s--read-only-port=[1-9][0-9]*(\\s|$)\"; then"
	elif ps -ef | grep kubelet | grep -v grep | grep -E -q "\s--read-only-port=[1-9][0-9]*(\s|$)"; then
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: --read-only-port is set to non-zero (Flag)")
		echo "[FAIL_REASON] Check Failed: --read-only-port is set to non-zero (Flag)"
		echo "[FIX_HINT] Run remediation script: 4.2.4_remediate.sh"
	
	# 3. Priority 2: Check Config File
	elif [ -f "$config_path" ]; then
		echo "[CMD] Executing: if grep -E -q \"readOnlyPort:\\s*0\" \"$config_path\"; then"
		if grep -E -q "readOnlyPort:\s*0" "$config_path"; then
			echo "[INFO] Check Passed"
			a_output+=(" - Check Passed: readOnlyPort is set to 0 in $config_path")
		else
			echo "[INFO] Check Failed"
			a_output2+=(" - Check Failed: readOnlyPort is NOT set to 0 in $config_path (or missing)")
			echo "[FAIL_REASON] Check Failed: readOnlyPort is NOT set to 0 in $config_path (or missing)"
			echo "[FIX_HINT] Run remediation script: 4.2.4_remediate.sh"
		fi
	
	# 4. Priority 3: Default
	else
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: --read-only-port not set and config file not found (Default: 10255/insecure)")
		echo "[FAIL_REASON] Check Failed: --read-only-port not set and config file not found (Default: 10255/insecure)"
		echo "[FIX_HINT] Run remediation script: 4.2.4_remediate.sh"
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
