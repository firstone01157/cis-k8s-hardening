#!/bin/bash
# CIS Benchmark: 1.3.5
# Title: Ensure that the --root-ca-file argument is set as appropriate (Automated)
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 1.3.5..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	echo "[CMD] Executing: if ps -ef | grep kube-controller-manager | grep -v grep | grep -E -q \"\\s--root-ca-file(=|\\s|$)\"; then"
	if ps -ef | grep kube-controller-manager | grep -v grep | grep -E -q "\s--root-ca-file(=|\s|$)"; then
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: --root-ca-file is set")
	else
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: --root-ca-file is not set")
		echo "[FAIL_REASON] Check Failed: --root-ca-file is not set"
		echo "[FIX_HINT] Run remediation script: 1.3.5_remediate.sh"
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
