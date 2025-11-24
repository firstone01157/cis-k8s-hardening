#!/bin/bash
# CIS Benchmark: 1.2.3
# Title: Ensure that the DenyServiceExternalIPs is set (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	if ps -ef | grep kube-apiserver | grep -v grep | grep -- "--enable-admission-plugins" | grep -q "DenyServiceExternalIPs"; then
		a_output+=(" - Check Passed: DenyServiceExternalIPs is enabled")
	else
		a_output2+=(" - Check Failed: DenyServiceExternalIPs is NOT enabled")
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
