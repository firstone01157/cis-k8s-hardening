#!/bin/bash
# CIS Benchmark: 1.2.6
# Title: Ensure that the --authorization-mode argument is not set to AlwaysAllow (Automated)
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 1.2.6..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	echo "[CMD] Executing: if ps -ef | grep kube-apiserver | grep -v grep | grep -E -- \"--authorization-mode=.*AlwaysAllow\"; then"
	if ps -ef | grep kube-apiserver | grep -v grep | grep -E -- "--authorization-mode=.*AlwaysAllow"; then
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: --authorization-mode contains AlwaysAllow")
		echo "[FAIL_REASON] Check Failed: --authorization-mode contains AlwaysAllow"
		echo "[FIX_HINT] Run remediation script: 1.2.6_remediate.sh"
	else
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: --authorization-mode does not contain AlwaysAllow")
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
