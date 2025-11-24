#!/bin/bash
# CIS Benchmark: 1.2.22
# Title: Ensure that the --service-account-key-file argument is set as appropriate (Automated)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this command specifically
	## Description from CSV:
	## Run the following command on the Control Plane node: ps -ef | grep kube-apiserver Verify that the --service-account-key-file argument exists and is set as appropriate.
	##
	## Command hint: Run the following command on the Control Plane node: ps -ef | grep kube-apiserver Verify that the --service-account-key-file argument exists and is set as appropriate.
	##
	## Placeholder logic (Fail by default until reviewed)
	## Change "1" to "0" once you implement the actual check

	if ps -ef | grep kube-apiserver | grep -v grep | grep -q -- "--service-account-key-file"; then
		a_output+=(" - Check Passed: --service-account-key-file is set")
	else
		a_output2+=(" - Check Failed: --service-account-key-file is not set")
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
