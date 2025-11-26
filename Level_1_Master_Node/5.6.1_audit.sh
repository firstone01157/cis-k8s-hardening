#!/bin/bash
# CIS Benchmark: 5.6.1
# Title: Create administrative boundaries between resources using namespaces (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# Check that multiple namespaces exist beyond default ones (system, default, kube-public, kube-node-lease)
	total_namespaces=$(kubectl get namespaces -o json 2>/dev/null | jq '.items | length')
	non_system_namespaces=$(kubectl get namespaces -o json 2>/dev/null | jq '[.items[] | select(.metadata.name | IN("default","kube-system","kube-public","kube-node-lease") | not)] | length')
	
	if [ "$non_system_namespaces" -gt 0 ]; then
		a_output+=(" - Check Passed: Administrative boundaries using namespaces are in place")
		a_output+=(" - Total namespaces: $total_namespaces")
		a_output+=(" - Custom namespaces (excluding system): $non_system_namespaces")
	else
		a_output2+=(" - Check Failed: No custom administrative boundaries found")
		a_output2+=(" - Only system namespaces exist. Create custom namespaces for workload isolation.")
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
