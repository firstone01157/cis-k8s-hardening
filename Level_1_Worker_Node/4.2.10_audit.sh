#!/bin/bash
# CIS Benchmark: 4.2.10
# Title: Ensure that the --rotate-certificates argument is not set to false (Automated)
# Level: • Level 1 - Worker Node

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/kubelet_helpers.sh"

audit_rule() {
	echo "[INFO] Starting check for 4.2.10..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# 1. Detect Config File
	echo "[CMD] Executing: config_path=$(kubelet_config_path)"
	config_path=$(kubelet_config_path)

	# 2. Priority 1: Check Flag
	echo "[CMD] Executing: if ps -ef | grep kubelet | grep -v grep | grep -E -q \"\\s--rotate-certificates=false(\\s|$)\"; then"
	if ps -ef | grep kubelet | grep -v grep | grep -E -q "\s--rotate-certificates=false(\s|$)"; then
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: --rotate-certificates is set to false (Flag)")
		echo "[FAIL_REASON] Check Failed: --rotate-certificates is set to false (Flag)"
		echo "[FIX_HINT] Run remediation script: 4.2.10_remediate.sh"
	echo "[CMD] Executing: elif ps -ef | grep kubelet | grep -v grep | grep -E -q \"\\s--rotate-certificates=true(\\s|$)\"; then"
	elif ps -ef | grep kubelet | grep -v grep | grep -E -q "\s--rotate-certificates=true(\s|$)"; then
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: --rotate-certificates is set to true (Flag)")
	
	# 3. Priority 2: Check Config File
	elif [ -f "$config_path" ]; then
		echo "[CMD] Executing: if grep -E -q \"rotateCertificates:\\s*false\" \"$config_path\"; then"
		if grep -E -q "rotateCertificates:\s*false" "$config_path"; then
			echo "[INFO] Check Failed"
			a_output2+=(" - Check Failed: rotateCertificates is set to false in $config_path")
			echo "[FAIL_REASON] Check Failed: rotateCertificates is set to false in $config_path"
			echo "[FIX_HINT] Run remediation script: 4.2.10_remediate.sh"
		else
			echo "[INFO] Check Passed"
			a_output+=(" - Check Passed: rotateCertificates is not set to false in $config_path (Default: true)")
		fi
	
	# 4. Priority 3: Default
	else
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: --rotate-certificates not set (Default: true)")
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
