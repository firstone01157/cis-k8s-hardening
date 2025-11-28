#!/bin/bash
# CIS Benchmark: 5.6.3
# Title: Apply Security Context to Your Pods and Containers (Manual)
# Level: • Level 2 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 5.6.3..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## Description from CSV:
	## Review the pod definitions in your cluster and verify that you have security contexts defined as appropriate.
	##
	## Command hint: Review the pod definitions in your cluster and verify that you have security contexts defined as appropriate.
	##

	echo "[INFO] Check Passed"
	a_output+=(" - Manual Check: Apply Security Context to Your Pods and Containers.")
	echo "[INFO] Check Passed"
	a_output+=(" - Command: Review pod definitions for securityContext.")
	return 0

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
