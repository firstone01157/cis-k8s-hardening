#!/bin/bash
# CIS Benchmark: 1.2.24
# Title: Ensure that the --tls-cert-file and --tls-private-key-file arguments are set as appropriate (Automated)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	if ps -ef | grep kube-apiserver | grep -v grep | grep -q -- "--tls-cert-file" && \
	   ps -ef | grep kube-apiserver | grep -v grep | grep -q -- "--tls-private-key-file"; then
		a_output+=(" - Check Passed: --tls-cert-file and --tls-private-key-file are set")
	else
		a_output2+=(" - Check Failed: --tls-cert-file and/or --tls-private-key-file are not set")
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
