#!/bin/bash
# CIS Benchmark: 1.2.2
# Title: Ensure that the --token-auth-file parameter is not set (Automated)
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 1.2.2..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	echo "[CMD] Executing: if ps -ef | grep kube-apiserver | grep -v grep | grep -E -q \"\\s--token-auth-file(=|\\s|$)\"; then"
	if ps -ef | grep kube-apiserver | grep -v grep | grep -E -q "\s--token-auth-file(=|\s|$)"; then
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: --token-auth-file is present but should not be")
		echo "[FAIL_REASON] Check Failed: --token-auth-file is present but should not be"
		echo "[FIX_HINT] Run remediation script: 1.2.2_remediate.sh"
	else
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: --token-auth-file is not set")
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
