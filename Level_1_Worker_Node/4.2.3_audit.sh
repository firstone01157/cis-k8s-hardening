#!/bin/bash
# CIS Benchmark: 4.2.3
# Title: Ensure that the --client-ca-file argument is set as appropriate (Automated)
# Level: • Level 1 - Worker Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## Description from CSV:
	## Run the following command on each node: ps -ef | grep kubelet Verify that the --client-ca-file argument exists and is set to the location of the client certificate authority file. If the --client-ca-f
	##
	## Command hint: Run the following command on each node: ps -ef | grep kubelet Verify that the --client-ca-file argument exists and is set to the location of the client certificate authority file. If the --client-ca-file argument is not present, check that there is a Kubelet config file specified by --config, and that the file sets authentication: x509: clientCAFile to the location of the client certificate authority file.
	##

	if ps -ef | grep kubelet | grep -v grep | grep -q "\--client-ca-file"; then
		a_output+=(" - Check Passed: --client-ca-file is set")
	else
		a_output2+=(" - Check Failed: --client-ca-file is NOT set")
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
