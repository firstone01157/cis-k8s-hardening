#!/bin/bash
# CIS Benchmark: 2.5
# Title: Ensure that the --peer-client-cert-auth argument is set to true (Automated)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	if ps -ef | grep etcd | grep -v grep | grep -q -- "--peer-client-cert-auth=true"; then
		a_output+=(" - Check Passed: --peer-client-cert-auth is set to true")
	else
		a_output2+=(" - Check Failed: --peer-client-cert-auth is not set to true")
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
