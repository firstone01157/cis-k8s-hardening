#!/bin/bash
# CIS Benchmark: 1.2.8
# Title: Ensure that the --authorization-mode argument includes RBAC (Automated)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this command specifically
	## Description from CSV:
	## Run the following command on the Control Plane node: ps -ef | grep kube-apiserver Verify that the --authorization-mode argument exists and is set to a value to include RBAC.
	##
	## Command hint: Run the following command on the Control Plane node: ps -ef | grep kube-apiserver Verify that the --authorization-mode argument exists and is set to a value to include RBAC.
	##
	## Placeholder logic (Fail by default until reviewed)
	## Change "1" to "0" once you implement the actual check

	if ps -ef | grep kube-apiserver | grep -v grep | grep -- "--authorization-mode" | grep -q "RBAC"; then
		a_output+=(" - Check Passed: --authorization-mode includes RBAC")
	else
		a_output2+=(" - Check Failed: --authorization-mode does not include RBAC")
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
