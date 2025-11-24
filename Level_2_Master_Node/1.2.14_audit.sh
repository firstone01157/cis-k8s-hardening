#!/bin/bash
# CIS Benchmark: 1.2.14
# Title: Ensure that the admission control plugin NodeRestriction is set (Automated)
# Level: • Level 2 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	if ps -ef | grep kube-apiserver | grep -v grep | grep "\--enable-admission-plugins" | grep -q "NodeRestriction"; then
		a_output+=(" - Check Passed: NodeRestriction is present in --enable-admission-plugins")
	else
		a_output2+=(" - Check Failed: NodeRestriction is NOT present in --enable-admission-plugins")
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
