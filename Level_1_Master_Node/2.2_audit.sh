#!/bin/bash
# CIS Benchmark: 2.2
# Title: Ensure that the --client-cert-auth argument is set to true (Automated)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this command specifically
	## Description from CSV:
	## Run the following command on the etcd server node: ps -ef | grep etcd Verify that the --client-cert-auth argument is set to true.
	##
	## Command hint: Run the following command on the etcd server node: ps -ef | grep etcd Verify that the --client-cert-auth argument is set to true.
	##
	## Placeholder logic (Fail by default until reviewed)
	## Change "1" to "0" once you implement the actual check

	if ps -ef | grep etcd | grep -v grep | grep -q -- "--client-cert-auth=true"; then
		a_output+=(" - Check Passed: --client-cert-auth is set to true")
	else
		a_output2+=(" - Check Failed: --client-cert-auth is not set to true")
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
