#!/bin/bash
# CIS Benchmark: 1.3.3
# Title: Ensure that the --use-service-account-credentials argument is set to true (Automated)
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 1.3.3..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	echo "[CMD] Executing: if ps -ef | grep kube-controller-manager | grep -v grep | grep -E -q \"\\s--use-service-account-credentials=true(\\s|$)\"; then"
	if ps -ef | grep kube-controller-manager | grep -v grep | grep -E -q "\s--use-service-account-credentials=true(\s|$)"; then
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: --use-service-account-credentials is set to true")
	else
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: --use-service-account-credentials is not set to true")
		echo "[FAIL_REASON] Check Failed: --use-service-account-credentials is not set to true"
		echo "[FIX_HINT] Run remediation script: 1.3.3_remediate.sh"
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
