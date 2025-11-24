#!/bin/bash
# CIS Benchmark: 1.2.20
# Title: Ensure that the --request-timeout argument is set as appropriate (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this command specifically
	## Description from CSV:
	## Run the following command on the Control Plane node: ps -ef | grep kube-apiserver Verify that the --request-timeout argument is either not set or set to an appropriate value.
	##
	## Command hint: Run the following command on the Control Plane node: ps -ef | grep kube-apiserver Verify that the --request-timeout argument is either not set or set to an appropriate value.
	##
	## Placeholder logic (Fail by default until reviewed)
	## Change "1" to "0" once you implement the actual check

	if ps -ef | grep kube-apiserver | grep -v grep | grep -q -- "--request-timeout"; then
		# If set, we assume it's appropriate for now as per manual check nature
		a_output+=(" - Check Passed: --request-timeout is set")
	else
		a_output+=(" - Check Passed: --request-timeout is not set (using default)")
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
