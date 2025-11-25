#!/bin/bash
# CIS Benchmark: 5.3.2
# Title: Ensure that all Namespaces have Network Policies defined (Manual)
# Level: • Level 2 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## Description from CSV:
	## Run the below command and review the NetworkPolicy objects created in the cluster. kubectl get networkpolicy --all-namespaces Ensure that each namespace defined in the cluster has at least one Network
	##
	## Command hint: and review the NetworkPolicy objects created in the cluster. kubectl get networkpolicy --all-namespaces Ensure that each namespace defined in the cluster has at least one Network Policy.
	##

	a_output+=(" - Manual Check: Ensure all Namespaces have Network Policies defined.")
	a_output+=(" - Command: kubectl get networkpolicy --all-namespaces")
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
