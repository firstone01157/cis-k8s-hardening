#!/bin/bash
# CIS Benchmark: 5.1.5
# Title: Ensure that default service accounts are not actively used. (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 5.1.5..."
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
		echo "[FIX_HINT] Run remediation script: 5.1.5_remediate.sh"
		printf '%s\n' "" "- Audit Result:" "  [-] ERROR" "${a_output2[@]}"
		return 2
	fi

	# Get all pods using the default service account, excluding kube-system
	echo "[CMD] Executing: kubectl get pods --all-namespaces -o json | jq filter for default service accounts"
	violations=$(kubectl get pods --all-namespaces -o json 2>/dev/null | jq -r '.items[] | select(.metadata.namespace != "kube-system") | select(.spec.serviceAccountName == "default") | "\(.metadata.namespace)/\(.metadata.name)"' | sort -u)
	
	if [ -n "$violations" ]; then
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: Pods using default service account found in non-system namespaces:")
		echo "[FAIL_REASON] Check Failed: Pods using default service account found in non-system namespaces:"
		echo "[FIX_HINT] Run remediation script: 5.1.5_remediate.sh"
		while IFS= read -r line; do
			[ -n "$line" ] && echo "[INFO] Check Failed"
			[ -n "$line" ] && a_output2+=(" - $line")
 echo "[FAIL_REASON] $line"
 echo "[FIX_HINT] Run remediation script: 5.1.5_remediate.sh"
		done <<< "$violations"
	else
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: No pods actively using default service account (excluding kube-system)")
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
