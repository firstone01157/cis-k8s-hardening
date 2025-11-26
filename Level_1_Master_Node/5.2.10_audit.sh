#!/bin/bash
# CIS Benchmark: 5.2.10
# Title: Minimize the admission of Windows HostProcess Containers (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# Check for containers with Windows HostProcess enabled
	hostprocess_pods=$(kubectl get pods -A -o json 2>/dev/null | jq -r '.items[] | select((.spec.containers[]?.securityContext.windowsOptions.hostProcess==true) or (.spec.initContainers[]?.securityContext.windowsOptions.hostProcess==true)) | "\(.metadata.namespace)/\(.metadata.name)"')
	
	if [ -z "$hostprocess_pods" ]; then
		a_output+=(" - Check Passed: No Windows HostProcess containers found")
	else
		a_output2+=(" - Check Failed: Found Windows HostProcess containers:")
		while IFS= read -r pod; do
			a_output2+=(" - Pod: $pod")
		done <<< "$hostprocess_pods"
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
