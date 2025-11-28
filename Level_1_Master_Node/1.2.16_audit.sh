#!/bin/bash
# CIS Benchmark: 1.2.16
# Title: Ensure that the --audit-log-path argument is set (Automated)
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 1.2.16..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	echo "[CMD] Executing: if ps -ef | grep kube-apiserver | grep -v grep | grep -E -q \"\\s--audit-log-path(=|\\s|$)\"; then"
	if ps -ef | grep kube-apiserver | grep -v grep | grep -E -q "\s--audit-log-path(=|\s|$)"; then
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: --audit-log-path is set")
	else
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: --audit-log-path is not set")
		echo "[FAIL_REASON] Check Failed: --audit-log-path is not set"
		echo "[FIX_HINT] Run remediation script: 1.2.16_remediate.sh"
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
