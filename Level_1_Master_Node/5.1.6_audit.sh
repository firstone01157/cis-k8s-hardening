#!/bin/bash
# CIS Benchmark: 5.1.6
# Title: Ensure that Service Account Tokens are only mounted where necessary (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 5.1.6..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# Get all pods with automountServiceAccountToken = true (or not explicitly set to false)
	echo "[CMD] Executing: kubectl get pods -A -o json | jq filter for automountServiceAccountToken"
	violations=$(kubectl get pods -A -o json 2>/dev/null | jq -r '.items[] | select(.metadata.namespace | test("^(kube-system|kube-public|kube-node-lease)$") | not) | select((.spec.automountServiceAccountToken // true) == true) | "\(.metadata.namespace)/\(.metadata.name)"' | sort -u)
	
	if [ -n "$violations" ]; then
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: Pods with automountServiceAccountToken=true found:")
		echo "[FAIL_REASON] Check Failed: Pods with automountServiceAccountToken=true found:"
		echo "[FIX_HINT] Run remediation script: 5.1.6_remediate.sh"
		while IFS= read -r line; do
			[ -n "$line" ] && echo "[INFO] Check Failed"
			[ -n "$line" ] && a_output2+=(" - $line")
 echo "[FAIL_REASON] $line"
 echo "[FIX_HINT] Run remediation script: 5.1.6_remediate.sh"
		done <<< "$violations"
	else
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: All pods have automountServiceAccountToken explicitly disabled")
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
