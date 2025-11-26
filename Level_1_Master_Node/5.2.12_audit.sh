#!/bin/bash
# CIS Benchmark: 5.2.12
# Title: Minimize the admission of containers which use HostPorts (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# Check for containers with HostPorts defined
	hostport_pods=$(kubectl get pods -A -o json 2>/dev/null | jq -r '.items[] | select((.spec.containers[]?.ports[]?.hostPort!=null) or (.spec.initContainers[]?.ports[]?.hostPort!=null)) | "\(.metadata.namespace)/\(.metadata.name)" + " - Ports: " + (([.spec.containers[]?.ports[]?.hostPort?, .spec.initContainers[]?.ports[]?.hostPort?] | map(select(!=null) | tostring) | join(",")) // "")')
	
	if [ -z "$hostport_pods" ]; then
		a_output+=(" - Check Passed: No containers with HostPorts found")
	else
		a_output2+=(" - Check Failed: Found containers with HostPorts:")
		while IFS= read -r pod; do
			a_output2+=(" - Pod: $pod")
		done <<< "$hostport_pods"
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
