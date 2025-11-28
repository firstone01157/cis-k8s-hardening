#!/bin/bash
# CIS Benchmark: 5.1.3
# Title: Minimize wildcard use in Roles and ClusterRoles (Automated)
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 5.1.3..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	echo "[CMD] Executing: # Verify kubectl is available"
	# Verify kubectl is available
	echo "[CMD] Executing: if ! command -v kubectl &> /dev/null; then"
	if ! command -v kubectl &> /dev/null; then
		echo "[CMD] Executing: a_output2+=(\" - Check Error: kubectl command not found\")"
		a_output2+=(" - Check Error: kubectl command not found")
		echo "[FAIL_REASON] Check Error: kubectl command not found"
		echo "[FIX_HINT] Run remediation script: 5.1.3_remediate.sh"
		printf '%s\n' "" "- Audit Result:" "  [-] ERROR" "${a_output2[@]}"
		return 2
	fi

	# Get all Roles and ClusterRoles with wildcard permissions
	# Exclude system roles
	echo "[CMD] Executing: violations=$(kubectl get roles,clusterroles -A -o json 2>/dev/null | jq -r '.items[] | select(.metadata.name | test(\"^(system:|kubeadm:)\") | not) | select(.rules[]? | select(.resources[]? == \"*\" or .verbs[]? == \"*\")) | \"\\(.kind): \\(.metadata.namespace):\\(.metadata.name)\"' | sort -u)"
	violations=$(kubectl get roles,clusterroles -A -o json 2>/dev/null | jq -r '.items[] | select(.metadata.name | test("^(system:|kubeadm:)") | not) | select(.rules[]? | select(.resources[]? == "*" or .verbs[]? == "*")) | "\(.kind): \(.metadata.namespace):\(.metadata.name)"' | sort -u)
	
	if [ -n "$violations" ]; then
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: Roles/ClusterRoles with wildcard permissions found:")
		echo "[FAIL_REASON] Check Failed: Roles/ClusterRoles with wildcard permissions found:"
		echo "[FIX_HINT] Run remediation script: 5.1.3_remediate.sh"
		while IFS= read -r line; do
			[ -n "$line" ] && echo "[INFO] Check Failed"
			[ -n "$line" ] && a_output2+=(" - $line")
 echo "[FAIL_REASON] $line"
 echo "[FIX_HINT] Run remediation script: 5.1.3_remediate.sh"
		done <<< "$violations"
	else
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: No non-system Roles/ClusterRoles with wildcard permissions found")
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
