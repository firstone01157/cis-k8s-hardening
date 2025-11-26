#!/bin/bash
# CIS Benchmark: 5.1.8
# Title: Limit use of the Bind, Impersonate and Escalate permissions in the Kubernetes cluster (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# Get all Roles and ClusterRoles with bind, impersonate, or escalate permissions
	violations=$(kubectl get roles,clusterroles -A -o json 2>/dev/null | jq -r '.items[] | select(.rules[]? | select(.verbs[]? | select(. == "bind" or . == "impersonate" or . == "escalate"))) | "\(.kind): \(.metadata.namespace):\(.metadata.name)"' | sort -u)
	
	if [ -n "$violations" ]; then
		a_output2+=(" - Check Failed: Roles/ClusterRoles with bind/impersonate/escalate permissions found:")
		while IFS= read -r line; do
			[ -n "$line" ] && a_output2+=(" - $line")
		done <<< "$violations"
	else
		a_output+=(" - Check Passed: No Roles/ClusterRoles with bind/impersonate/escalate permissions")
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
