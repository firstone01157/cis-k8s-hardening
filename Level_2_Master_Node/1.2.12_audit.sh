#!/bin/bash
# CIS Benchmark: 1.2.12
# Title: Ensure that the admission control plugin ServiceAccount is set (Automated)
# Level: • Level 2 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	if ps -ef | grep kube-apiserver | grep -v grep | grep -q "\--disable-admission-plugins"; then
		if ps -ef | grep kube-apiserver | grep -v grep | grep "\--disable-admission-plugins" | grep -q "ServiceAccount"; then
			a_output2+=(" - Check Failed: ServiceAccount is present in --disable-admission-plugins")
		else
			a_output+=(" - Check Passed: ServiceAccount is not in --disable-admission-plugins")
		fi
	else
		a_output+=(" - Check Passed: --disable-admission-plugins is not set")
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
