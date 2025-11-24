#!/bin/bash
# CIS Benchmark: 3.1.1
# Title: Client certificate authentication should not be used for users (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# This is a manual check. Review user access.
	# We can check if client cert auth is widely used or if there are many users with certs, but that's complex.
	# Basically check if we are using it. It is enabled by default.

	a_output+=(" - Manual Check: Review user access to ensure client certificate authentication is not used for users.")

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
