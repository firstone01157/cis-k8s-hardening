#!/bin/bash
# CIS Benchmark: 3.1.2
# Title: Service account token authentication should not be used for users (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# This is a manual check.
	if ps -ef | grep kube-apiserver | grep -v grep | grep -q -- "--service-account-lookup=true"; then
		a_output+=(" - Manual Check: --service-account-lookup is set to true (Good). Ensure service account tokens are not used for users.")
	else
		a_output+=(" - Manual Check: --service-account-lookup is NOT set to true.")
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
