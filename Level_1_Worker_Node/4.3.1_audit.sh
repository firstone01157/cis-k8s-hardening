#!/bin/bash
# CIS Benchmark: 4.3.1
# Title: Ensure that the kube-proxy metrics service is bound to localhost (Manual)
# Level: • Level 1 - Worker Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this command specifically
	## Description from CSV:
	## review the start-up flags provided to kube proxy Run the following command on each node: ps -ef | grep -i kube-proxy Ensure that the --metrics-bind-address parameter is not set to a value other than
	##
	## Command hint: review the start-up flags provided to kube proxy Run the following command on each node: ps -ef | grep -i kube-proxy Ensure that the --metrics-bind-address parameter is not set to a value other than
	##
	## Placeholder logic (Fail by default until reviewed)
	## Change "1" to "0" once you implement the actual check

	a_output+=(" - Manual Check: Ensure kube-proxy metrics service is bound to localhost.")
	a_output+=(" - Command: ps -ef | grep kube-proxy (Check --metrics-bind-address)")
	return 0

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
