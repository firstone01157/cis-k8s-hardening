#!/bin/bash
# CIS Benchmark: 3.2.1
# Title: Ensure that a minimal audit policy is created (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this command specifically
	## Description from CSV:
	## Run the following command on one of the cluster master nodes: ps -ef | grep kube-apiserver Verify that the --audit-policy-file is set. Review the contents of the file specified and ensure that it cont
	##
	## Command hint: Run the following command on one of the cluster master nodes: ps -ef | grep kube-apiserver Verify that the --audit-policy-file is set. Review the contents of the file specified and ensure that it contains a valid audit policy.
	##
	## Placeholder logic (Fail by default until reviewed)
	## Change "1" to "0" once you implement the actual check

	if ps -ef | grep kube-apiserver | grep -v grep | grep -q -- "--audit-policy-file"; then
		a_output+=(" - Check Passed: --audit-policy-file is set")
	else
		a_output2+=(" - Check Failed: --audit-policy-file is not set")
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
