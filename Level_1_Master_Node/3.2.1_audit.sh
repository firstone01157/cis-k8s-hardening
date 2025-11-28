#!/bin/bash
# CIS Benchmark: 3.2.1
# Title: Ensure that a minimal audit policy is created (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 3.2.1..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	echo "[CMD] Executing: if ps -ef | grep kube-apiserver | grep -v grep | grep -q -- \"--audit-policy-file\"; then"
	if ps -ef | grep kube-apiserver | grep -v grep | grep -q -- "--audit-policy-file"; then
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: --audit-policy-file is set")
	else
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: --audit-policy-file is not set")
		echo "[FAIL_REASON] Check Failed: --audit-policy-file is not set"
		echo "[FIX_HINT] Run remediation script: 3.2.1_remediate.sh"
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
