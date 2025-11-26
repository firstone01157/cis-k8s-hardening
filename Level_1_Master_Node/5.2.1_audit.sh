#!/bin/bash
# CIS Benchmark: 5.2.1
# Title: Ensure that the cluster has at least one active policy control mechanism in place (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# Check for Pod Security Admission, PSP, or other policy control mechanisms
	# Method 1: Check for Pod Security Admission in kube-apiserver
	psa_enabled=$(ps -ef 2>/dev/null | grep kube-apiserver | grep -v grep | grep -q "enable-admission-plugins" && echo "found" || echo "not found")
	
	# Method 2: Check for PodSecurityPolicy resources
	psp_count=$(kubectl get podsecuritypolicies -o json 2>/dev/null | jq '.items | length')
	
	# Method 3: Check for any Pod Security Standards labels on namespaces
	pss_labels=$(kubectl get ns -o json 2>/dev/null | jq '[.items[] | select(.metadata.labels | select(. != null) | keys[] | select(startswith("pod-security.kubernetes.io")))] | length')
	
	if [ "$psp_count" -gt 0 ] || [ "$pss_labels" -gt 0 ] || [[ "$psa_enabled" == "found" ]]; then
		a_output+=(" - Check Passed: Pod Security policy control mechanism is active")
		[ "$psp_count" -gt 0 ] && a_output+=(" - PodSecurityPolicies found: $psp_count")
		[ "$pss_labels" -gt 0 ] && a_output+=(" - Pod Security Standards labels found on namespaces: $pss_labels")
		[[ "$psa_enabled" == "found" ]] && a_output+=(" - Pod Security Admission enabled in kube-apiserver")
	else
		a_output2+=(" - Check Failed: No active policy control mechanism found")
		a_output2+=(" - Ensure one of the following is configured:")
		a_output2+=(" - • Pod Security Admission (PSA) enabled in kube-apiserver")
		a_output2+=(" - • PodSecurityPolicy (PSP) resources deployed")
		a_output2+=(" - • Pod Security Standards labels applied to namespaces")
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
