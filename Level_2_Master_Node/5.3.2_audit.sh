#!/bin/bash
# CIS Benchmark: 5.3.2
# Title: Ensure that all Namespaces have Network Policies defined
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 5.3.2..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# Verify kubectl is available
	echo "[CMD] Executing: if ! command -v kubectl &> /dev/null; then"
	if ! command -v kubectl &> /dev/null; then
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Error: kubectl command not found")
		echo "[FAIL_REASON] Check Error: kubectl command not found"
		echo "[FIX_HINT] Ensure kubectl is installed and in the PATH."
		printf '%s\n' "" "- Audit Result:" "  [-] ERROR" "${a_output2[@]}"
		return 2
	fi

	# Check if each non-system namespace has at least one NetworkPolicy
	# Exclude system namespaces: kube-system, kube-public
	
	echo "[CMD] Executing: namespaces=$(kubectl get ns -o json 2>/dev/null | jq -r '.items[] | select(.metadata.name | test("^(kube-system|kube-public)$") | not) | .metadata.name')"
	namespaces=$(kubectl get ns -o json 2>/dev/null | jq -r '.items[] | select(.metadata.name | test("^(kube-system|kube-public)$") | not) | .metadata.name')
	
	failed_namespaces=""
	
	for ns in $namespaces; do
		echo "[CMD] Executing: count=$(kubectl get networkpolicies -n \"$ns\" --no-headers 2>/dev/null | wc -l)"
		count=$(kubectl get networkpolicies -n "$ns" --no-headers 2>/dev/null | wc -l)
		if [ "$count" -eq 0 ]; then
			failed_namespaces+="$ns "
		fi
	done
	
	if [ -n "$failed_namespaces" ]; then
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: The following namespaces have 0 NetworkPolicies:")
		echo "[FAIL_REASON] Check Failed: The following namespaces have 0 NetworkPolicies:"
		echo "[FIX_HINT] Run remediation script: 5.3.2_remediate.sh"
		for ns in $failed_namespaces; do
			echo "[INFO] Check Failed"
			a_output2+=(" - $ns")
			echo "[FAIL_REASON] $ns"
			echo "[FIX_HINT] Run remediation script: 5.3.2_remediate.sh"
		done
	else
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: All non-system namespaces have at least one NetworkPolicy")
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
