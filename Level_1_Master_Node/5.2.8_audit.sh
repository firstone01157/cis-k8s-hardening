#!/bin/bash
# CIS Benchmark: 5.2.8
# Title: Minimize the admission of containers with the NET_RAW capability (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# Check for containers with NET_RAW capability added
	netraw_pods=$(kubectl get pods -A -o json 2>/dev/null | jq -r '.items[] | select((.spec.containers[]?.securityContext.capabilities.add[]?=="NET_RAW") or (.spec.initContainers[]?.securityContext.capabilities.add[]?=="NET_RAW")) | "\(.metadata.namespace)/\(.metadata.name)"' | sort -u)
	
	if [ -z "$netraw_pods" ]; then
		a_output+=(" - Check Passed: No containers with NET_RAW capability found")
	else
		a_output2+=(" - Check Failed: Found containers with NET_RAW capability:")
		while IFS= read -r pod; do
			a_output2+=(" - Pod: $pod")
		done <<< "$netraw_pods"
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
