#!/bin/bash
# CIS Benchmark: 4.2.11
# Title: Verify that the RotateKubeletServerCertificate argument is set to true (Manual)
# Level: • Level 1 - Worker Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## Description from CSV:
	## Ignore this check if serverTLSBootstrap is true in the kubelet config file or if the --rotate- server-certificates parameter is set on kubelet Run the following command on each node: ps -ef | grep kub
	##
	## Command hint: Ignore this check if serverTLSBootstrap is true in the kubelet config file or if the --rotate- server-certificates parameter is set on kubelet Run the following command on each node: ps -ef | grep kubelet Verify that RotateKubeletServerCertificate argument exists and is set to true.
	##

	if ps -ef | grep kubelet | grep -v grep | grep -q "\--rotate-certificates=true"; then
		a_output+=(" - Check Passed: --rotate-certificates is set to true")
	else
		a_output2+=(" - Check Failed: --rotate-certificates is NOT set to true")
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
