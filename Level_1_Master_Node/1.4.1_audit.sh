#!/bin/bash
# CIS Benchmark: 1.4.1
# Title: Ensure that the --profiling argument is set to false (Automated)
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 1.4.1..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	echo "[CMD] Executing: if ps -ef | grep kube-scheduler | grep -v grep | grep -E -q \"\\s--profiling=false(\\s|$)\"; then"
	if ps -ef | grep kube-scheduler | grep -v grep | grep -E -q "\s--profiling=false(\s|$)"; then
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: --profiling is set to false")
	else
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: --profiling is not set to false")
		echo "[FAIL_REASON] Check Failed: --profiling is not set to false"
		echo "[FIX_HINT] Run remediation script: 1.4.1_remediate.sh"
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
