#!/bin/bash
# CIS Benchmark: 1.2.19
# Title: Ensure that the --audit-log-maxsize argument is set to 100 or as appropriate (Automated)
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 1.2.19..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	echo "[CMD] Executing: if ps -ef | grep kube-apiserver | grep -v grep | grep -E -q \"\\s--audit-log-maxsize(=|\\s|$)\"; then"
	if ps -ef | grep kube-apiserver | grep -v grep | grep -E -q "\s--audit-log-maxsize(=|\s|$)"; then
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: --audit-log-maxsize is set")
	else
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: --audit-log-maxsize is not set")
		echo "[FAIL_REASON] Check Failed: --audit-log-maxsize is not set"
		echo "[FIX_HINT] Run remediation script: 1.2.19_remediate.sh"
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
