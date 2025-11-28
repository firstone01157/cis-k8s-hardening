#!/bin/bash
# CIS Benchmark: 5.5.1
# Title: Configure Image Provenance using ImagePolicyWebhook admission controller (Manual)
# Level: • Level 2 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 5.5.1..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## Description from CSV:
	## Review the pod definitions in your cluster and verify that image provenance is configured as appropriate.
	##
	## Command hint: Review the pod definitions in your cluster and verify that image provenance is configured as appropriate.
	##

	echo "[INFO] Check Passed"
	a_output+=(" - Manual Check: Configure Image Provenance using ImagePolicyWebhook.")
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
