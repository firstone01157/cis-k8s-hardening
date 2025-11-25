#!/bin/bash
# CIS Benchmark: 4.2.1
# Title: Ensure that the --anonymous-auth argument is set to false (Automated)
# Level: • Level 1 - Worker Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## Description from CSV:
	## If using a Kubelet configuration file, check that there is an entry for authentication: anonymous: enabled set to false. Run the following command on each node: ps -ef | grep kubelet Verify that the -
	##
	## Command hint: If using a Kubelet configuration file, check that there is an entry for authentication: anonymous: enabled set to false. Run the following command on each node: ps -ef | grep kubelet Verify that the --anonymous-auth argument is set to false. This executable argument may be omitted, provided there is a corresponding entry set to false in the Kubelet config file.
	##

	if ps -ef | grep kubelet | grep -v grep | grep -q "\--anonymous-auth=false"; then
		a_output+=(" - Check Passed: --anonymous-auth is set to false")
	else
		a_output2+=(" - Check Failed: --anonymous-auth is NOT set to false")
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
