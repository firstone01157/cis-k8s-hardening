#!/bin/bash
# CIS Benchmark: 5.2.2
# Title: Minimize the admission of privileged containers (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# Check all pods across all namespaces for privileged:true in securityContext
	privileged_pods=$(kubectl get pods -A -o json 2>/dev/null | jq -r '.items[] | select(.spec.containers[]?.securityContext.privileged==true or .spec.initContainers[]?.securityContext.privileged==true) | "\(.metadata.namespace)/\(.metadata.name)"')
	
	if [ -z "$privileged_pods" ]; then
		a_output+=(" - Check Passed: No privileged containers found running in cluster")
	else
		a_output2+=(" - Check Failed: Found privileged containers:")
		while IFS= read -r pod; do
			a_output2+=(" - Pod: $pod")
		done <<< "$privileged_pods"
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
