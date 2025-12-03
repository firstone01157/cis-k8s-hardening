#!/bin/bash
# CIS Benchmark: 5.1.3
# Title: Minimize wildcard use in Roles and ClusterRoles (Automated)
# Level: • Level 1 - Master Node

set -x  # Enable debugging
set -euo pipefail

audit_rule() {
	echo "[INFO] Starting check for 5.1.3..."
	local -a a_output a_output2
	a_output=()
	a_output2=()

	echo "[CMD] Verifying kubectl is available"
	# Verify kubectl is available
	if ! command -v kubectl &> /dev/null; then
		echo "[ERROR] kubectl command not found"
		a_output2+=(" - Check Error: kubectl command not found")
		echo "[FAIL_REASON] Check Error: kubectl command not found"
		echo "[FIX_HINT] Run remediation script: 5.1.3_remediate.sh"
		printf '%s\n' "" "- Audit Result:" "  [-] ERROR" "${a_output2[@]}"
		return 2
	fi

	# Get all Roles and ClusterRoles with wildcard permissions
	# Exclude system roles
	echo "[CMD] Querying roles/clusterroles for wildcard permissions..."
	local violations
	# Use single quotes to avoid shell interpretation, then pass to jq
	violations=$(kubectl get roles,clusterroles -A -o json 2>/dev/null | \
		jq -r '.items[] | 
			select(.metadata.name | test("^(system:|kubeadm:)") | not) | 
			select(.rules[]? | select(.resources[]? == "*" or .verbs[]? == "*")) | 
			"\(.kind): \(.metadata.namespace):\(.metadata.name)"' \
		2>/dev/null | sort -u || echo "")
	echo "[DEBUG] violations result: ${violations:-<empty>}"

	if [ -n "$violations" ]; then
		echo "[INFO] Check Failed - Wildcard permissions found"
		a_output2+=(" - Check Failed: Roles/ClusterRoles with wildcard permissions found:")
		echo "[FAIL_REASON] Check Failed: Roles/ClusterRoles with wildcard permissions found:"
		echo "[FIX_HINT] Run remediation script: 5.1.3_remediate.sh"
		while IFS= read -r line; do
			[ -z "$line" ] && continue
			a_output2+=(" - $line")
			echo "[FAIL_REASON] $line"
			echo "[FIX_HINT] Review and restrict wildcard permissions"
		done <<< "$violations"
	else
		echo "[INFO] Check Passed - No wildcard permissions found"
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
RESULT="$?"
exit "${RESULT:-1}"
