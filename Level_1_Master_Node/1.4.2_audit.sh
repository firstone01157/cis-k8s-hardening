#!/bin/bash
# CIS Benchmark: 1.4.2
# Title: Ensure that the --bind-address argument is set to 127.0.0.1 (Automated)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this command specifically
	## Description from CSV:
	## Run the following command on the Control Plane node: ps -ef | grep kube-scheduler Verify that the --bind-address argument is set to 127.0.0.1
	##
	## Command hint: Run the following command on the Control Plane node: ps -ef | grep kube-scheduler Verify that the --bind-address argument is set to 127.0.0.1
	##
	## Placeholder logic (Fail by default until reviewed)
	## Change "1" to "0" once you implement the actual check

	if ps -ef | grep kube-scheduler | grep -v grep | grep -q -- "--bind-address=127.0.0.1"; then
		a_output+=(" - Check Passed: --bind-address is set to 127.0.0.1")
	else
		a_output2+=(" - Check Failed: --bind-address is not set to 127.0.0.1")
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
