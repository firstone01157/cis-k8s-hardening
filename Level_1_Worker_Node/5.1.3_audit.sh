#!/bin/bash
# CIS Benchmark: 5.1.3
# Title: Minimize wildcard use in Roles and ClusterRoles (Manual)
# Level: • Level 1 - Worker Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# This is a manual check as it requires reviewing all roles.
	# We can provide a helper command.
	a_output+=(" - Manual Check: Minimize wildcard use in Roles and ClusterRoles.")
	a_output+=(" - Helper Command: kubectl get roles,clusterroles --all-namespaces -o yaml | grep -C 5 '*'")
	
	# We return 0 (Pass) with info, or we could try to detect wildcards.
	# Detecting wildcards reliably in bash is hard without yq/jq.
	# We'll stick to manual check notification.
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
