#!/bin/bash
# CIS Benchmark: 5.2.7
# Title: Minimize the admission of root containers (Manual)
# Level: • Level 2 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# Verify kubectl and jq are available
	if ! command -v kubectl &> /dev/null || ! command -v jq &> /dev/null; then
		a_output2+=(" - Check Error: kubectl or jq command not found")
		printf '%s\n' "" "- Audit Result:" "  [-] ERROR" "${a_output2[@]}"
		return 2
	fi

	# Verify cluster is reachable
	if ! kubectl cluster-info &>/dev/null; then
		a_output2+=(" - Check Error: Unable to connect to Kubernetes cluster")
		printf '%s\n' "" "- Audit Result:" "  [-] ERROR" "${a_output2[@]}"
		return 2
	fi

	# Find all pods where runAsNonRoot is NOT set to true (meaning they allow running as root)
	# Use streaming pattern to avoid memory exhaustion on large clusters
	local root_containers
	root_containers=$(kubectl get pods -A -o json 2>/dev/null | jq -r '.items[] | select((.spec.containers[]?.securityContext.runAsNonRoot != true) or (.spec.initContainers[]?.securityContext.runAsNonRoot != true)) | "\(.metadata.namespace)/\(.metadata.name)"' | sort -u)
	
	if [ -z "$root_containers" ]; then
		a_output+=(" - Check Passed: All containers are configured to run as non-root")
	else
		a_output2+=(" - Check Failed: The following pods allow running containers as root:")
		while IFS= read -r pod; do
			[ -z "$pod" ] && continue
			a_output2+=(" - Pod: $pod")
		done <<< "$root_containers"
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
