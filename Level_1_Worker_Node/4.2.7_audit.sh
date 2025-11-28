#!/bin/bash
# CIS Benchmark: 4.2.7
# Title: Ensure that the --hostname-override argument is not set (Manual)
# Level: • Level 1 - Worker Node

audit_rule() {
	echo "[INFO] Starting check for 4.2.7..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# 1. Check Flag (Only source)
	echo "[CMD] Executing: if ps -ef | grep kubelet | grep -v grep | grep -E -q \"\\s--hostname-override(=|\\s|$)\"; then"
	if ps -ef | grep kubelet | grep -v grep | grep -E -q "\s--hostname-override(=|\s|$)"; then
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: --hostname-override is set")
		echo "[FAIL_REASON] Check Failed: --hostname-override is set"
		echo "[FIX_HINT] Run remediation script: 4.2.7_remediate.sh"
	else
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: --hostname-override is NOT set")
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
