#!/bin/bash
# CIS Benchmark: 1.2.28
# Title: Ensure that encryption providers are appropriately configured (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	if ps -ef | grep kube-apiserver | grep -v grep | grep -q -- "--encryption-provider-config"; then
		a_output+=(" - Check Passed: --encryption-provider-config is set (Manual verification of config file content required)")
	else
		a_output2+=(" - Check Failed: --encryption-provider-config is not set")
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
