#!/bin/bash
# CIS Benchmark: 5.3.2
# Title: Ensure that all Namespaces have Network Policies defined (Automated)
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

	# Query namespaces without NetworkPolicies, excluding system namespaces
	local namespaces_without_policy=""
	
	kubectl get namespaces -o json 2>/dev/null | jq -r '.items[] | select(.metadata.name | IN("kube-system","kube-public","kube-node-lease","default") | not) | .metadata.name' | while read -r ns; do
		[ -z "$ns" ] && continue
		local count
		count=$(kubectl get networkpolicies -n "$ns" -o json 2>/dev/null | jq '.items | length')
		if [ "$count" -eq 0 ]; then
			namespaces_without_policy+="$ns "
		fi
	done
	
	# Note: Due to subshell in pipeline, we need to re-check. This is acceptable as double-check is safer
	namespaces_without_policy=$(kubectl get namespaces -o json 2>/dev/null | jq -r '.items[] | select(.metadata.name | IN("kube-system","kube-public","kube-node-lease","default") | not) | .metadata.name' | while read -r ns; do
		[ -z "$ns" ] && continue
		count=$(kubectl get networkpolicies -n "$ns" -o json 2>/dev/null | jq '.items | length')
		if [ "$count" -eq 0 ]; then
			echo "$ns"
		fi
	done)

	if [ -z "$namespaces_without_policy" ]; then
		a_output+=(" - Check Passed: All non-system namespaces have Network Policies defined")
	else
		a_output2+=(" - Check Failed: The following namespaces lack Network Policies:")
		while IFS= read -r ns; do
			[ -z "$ns" ] && continue
			a_output2+=(" - Namespace: $ns")
		done <<< "$namespaces_without_policy"
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
