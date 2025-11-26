#!/bin/bash
# CIS Benchmark: 5.2.5
# Title: Minimize the admission of containers wishing to share the host network namespace (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# Check for pods with hostNetwork:true
	hostnetwork_pods=$(kubectl get pods -A -o json 2>/dev/null | jq -r '.items[] | select(.spec.hostNetwork==true) | "\(.metadata.namespace)/\(.metadata.name)"')
	
	if [ -z "$hostnetwork_pods" ]; then
		a_output+=(" - Check Passed: No pods with hostNetwork:true found")
	else
		a_output2+=(" - Check Failed: Found pods with hostNetwork sharing host network namespace:")
		while IFS= read -r pod; do
			a_output2+=(" - Pod: $pod")
		done <<< "$hostnetwork_pods"
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
