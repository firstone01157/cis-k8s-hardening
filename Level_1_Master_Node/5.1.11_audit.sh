#!/bin/bash
# CIS Benchmark: 5.1.11
# Title: Minimize access to the approval sub-resource of certificatesigningrequests objects (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 5.1.11..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# Get all Roles and ClusterRoles with certificatesigningrequests/approval access
	echo "[CMD] Executing: kubectl get roles,clusterroles -A -o json | jq filter for CSR approval"
	violations=$(kubectl get roles,clusterroles -A -o json 2>/dev/null | jq -r '.items[] | select(.metadata.name | test("^(system:|kubeadm:)") | not) | select(.rules[]? | select((.resources[]? | select(. == "certificatesigningrequests/approval" or . == "certificatesigningrequests")) and (.verbs[]? == "*" or .verbs[]? == "create" or .verbs[]? == "update" or .verbs[]? == "patch"))) | "\(.kind): \(.metadata.namespace):\(.metadata.name)"' | sort -u)
	
	if [ -n "$violations" ]; then
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: Roles/ClusterRoles with CSR approval access found:")
		echo "[FAIL_REASON] Check Failed: Roles/ClusterRoles with CSR approval access found:"
		echo "[FIX_HINT] Run remediation script: 5.1.11_remediate.sh"
		while IFS= read -r line; do
			[ -n "$line" ] && echo "[INFO] Check Failed"
			[ -n "$line" ] && a_output2+=(" - $line")
 echo "[FAIL_REASON] $line"
 echo "[FIX_HINT] Run remediation script: 5.1.11_remediate.sh"
		done <<< "$violations"
	else
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: No Roles/ClusterRoles with CSR approval access")
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
