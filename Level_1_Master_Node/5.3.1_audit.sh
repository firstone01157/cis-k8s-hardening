#!/bin/bash
# CIS Benchmark: 5.3.1
# Title: Ensure that the CNI in use supports Network Policies (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# Check for existence of NetworkPolicy resources in the cluster
	networkpolicies=$(kubectl get networkpolicies -A -o json 2>/dev/null | jq -r '.items | length')
	
	if [ "$networkpolicies" -gt 0 ]; then
		a_output+=(" - Check Passed: NetworkPolicy resources found in cluster")
		a_output+=(" - Network Policies defined: $networkpolicies")
	else
		a_output2+=(" - Check Failed: No NetworkPolicy resources found")
		a_output2+=(" - Ensure CNI plugin supports Network Policies (e.g., Calico, Weave, Cilium)")
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
