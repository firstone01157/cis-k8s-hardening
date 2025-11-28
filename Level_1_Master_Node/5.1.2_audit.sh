#!/bin/bash
# CIS Benchmark: 5.1.2
# Title: Minimize access to secrets (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 5.1.2..."
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
		echo "[FIX_HINT] Run remediation script: 5.1.2_remediate.sh"
		printf '%s\n' "" "- Audit Result:" "  [-] ERROR" "${a_output2[@]}"
		return 2
	fi

	# Get all ClusterRoles (and Roles) with secrets * permissions
	# Focus on ClusterRoles as they are cluster-wide
	# Exclude system roles (starting with "system:") as they legitimately need access
	echo "[CMD] Executing: kubectl get clusterroles -o json | jq filter for secrets access"
	violations=$(kubectl get clusterroles -o json 2>/dev/null | jq -r '.items[] | select(.metadata.name | test("^system:") | not) | select(.rules[]? | select(.resources[]? == "secrets" and (.verbs[]? == "*" or .verbs[]? == "get" or .verbs[]? == "list" or .verbs[]? == "watch"))) | "ClusterRole: \(.metadata.name)"' | sort -u)
	
	# Also check Roles if needed, but the prompt emphasized ClusterRole. 
	# Adding Roles check as well for completeness but labeling them clearly.
	# Also excluding system roles here.
	echo "[CMD] Executing: kubectl get roles -A -o json | jq filter for secrets access"
	role_violations=$(kubectl get roles -A -o json 2>/dev/null | jq -r '.items[] | select(.metadata.name | test("^system:") | not) | select(.rules[]? | select(.resources[]? == "secrets" and (.verbs[]? == "*" or .verbs[]? == "get" or .verbs[]? == "list" or .verbs[]? == "watch"))) | "Role: \(.metadata.namespace)/\(.metadata.name)"' | sort -u)

	if [ -n "$violations" ] || [ -n "$role_violations" ]; then
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: Found non-system Roles/ClusterRoles with secrets access:")
		echo "[FAIL_REASON] Check Failed: Found non-system Roles/ClusterRoles with secrets access:"
		echo "[FIX_HINT] Run remediation script: 5.1.2_remediate.sh"
		while IFS= read -r line; do
			[ -n "$line" ] && echo "[INFO] Check Failed"
			[ -n "$line" ] && a_output2+=(" - $line")
 echo "[FAIL_REASON] $line"
 echo "[FIX_HINT] Run remediation script: 5.1.2_remediate.sh"
		done <<< "$violations"
		while IFS= read -r line; do
			[ -n "$line" ] && echo "[INFO] Check Failed"
			[ -n "$line" ] && a_output2+=(" - $line")
 echo "[FAIL_REASON] $line"
 echo "[FIX_HINT] Run remediation script: 5.1.2_remediate.sh"
		done <<< "$role_violations"
	else
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: No non-system Roles/ClusterRoles with overly broad secrets access")
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
