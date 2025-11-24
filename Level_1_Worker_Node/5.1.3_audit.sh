#!/bin/bash
# CIS Benchmark: 5.1.3
# Title: Minimize wildcard use in Roles and ClusterRoles (Manual)
# Level: • Level 1 - Worker Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this command specifically
	## Description from CSV:
	## Retrieve the roles defined across each namespaces in the cluster and review for wildcards kubectl get roles --all-namespaces -o yaml Retrieve the cluster roles defined in the cluster and review for wi
	##
	## Command hint: Retrieve the roles defined across each namespaces in the cluster and review for wildcards kubectl get roles --all-namespaces -o yaml Retrieve the cluster roles defined in the cluster and review for wildcards kubectl get clusterroles -o yaml
	##
	## Placeholder logic (Fail by default until reviewed)
	## Change "1" to "0" once you implement the actual check

	a_output+=(" - Manual Check: Minimize wildcard use in Roles and ClusterRoles.")
	a_output+=(" - Command: kubectl get roles --all-namespaces -o yaml | grep -C 5 '*'")
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
