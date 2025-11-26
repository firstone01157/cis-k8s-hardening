#!/bin/bash
# CIS Benchmark: 5.1.11
# Title: Minimize access to the approval sub-resource of certificatesigningrequests objects (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# Get all Roles and ClusterRoles with certificatesigningrequests/approval access
	violations=$(kubectl get roles,clusterroles -A -o json 2>/dev/null | jq -r '.items[] | select(.rules[]? | select((.resources[]? | select(. == "certificatesigningrequests/approval" or . == "certificatesigningrequests")) and (.verbs[]? == "*" or .verbs[]? == "create" or .verbs[]? == "update" or .verbs[]? == "patch"))) | "\(.kind): \(.metadata.namespace):\(.metadata.name)"' | sort -u)
	
	if [ -n "$violations" ]; then
		a_output2+=(" - Check Failed: Roles/ClusterRoles with CSR approval access found:")
		while IFS= read -r line; do
			[ -n "$line" ] && a_output2+=(" - $line")
		done <<< "$violations"
	else
		a_output+=(" - Check Passed: No Roles/ClusterRoles with CSR approval access")
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
