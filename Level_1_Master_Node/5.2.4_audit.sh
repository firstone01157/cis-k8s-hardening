#!/bin/bash
# CIS Benchmark: 5.2.4
# Title: Minimize the admission of containers wishing to share the host IPC namespace
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 5.2.4..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# Verify kubectl and jq are available
	if ! command -v kubectl &> /dev/null; then
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Error: kubectl command not found")
		echo "[FAIL_REASON] Check Error: kubectl command not found"
		echo "[FIX_HINT] Ensure kubectl is installed and in the PATH."
		printf '%s\n' "" "- Audit Result:" "  [-] ERROR" "${a_output2[@]}"
		return 2
	fi
	
	if ! command -v jq &> /dev/null; then
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Error: jq command not found")
		echo "[FAIL_REASON] Check Error: jq command not found"
		echo "[FIX_HINT] Ensure jq is installed and in the PATH."
		printf '%s\n' "" "- Audit Result:" "  [-] ERROR" "${a_output2[@]}"
		return 2
	fi

	# Check for namespaces missing the label
	echo "[CMD] Executing: kubectl get ns -o json"
	ns_json=$(kubectl get ns -o json 2>/dev/null)
	
	echo "[CMD] Executing: jq filter for namespaces without enforce label"
	missing_labels=$(echo "$ns_json" | jq -r '.items[] | select(.metadata.name != "kube-system" and .metadata.name != "kube-public") | select(.metadata.labels["pod-security.kubernetes.io/enforce"] == null) | .metadata.name')

	if [ -n "$missing_labels" ]; then
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: The following namespaces are missing 'pod-security.kubernetes.io/enforce' label:")
		echo "[FAIL_REASON] Check Failed: Namespaces missing PSS enforcement label"
		echo "[FIX_HINT] Run remediation script: 5.2.4_remediate.sh"
		for ns in $missing_labels; do
			 a_output2+=(" - $ns")
		done
		printf '%s\n' "" "- Audit Result:" "  [-] FAIL" " - Reason(s) for audit failure:" "${a_output2[@]}"
		return 1
	else
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: All non-system namespaces have 'pod-security.kubernetes.io/enforce' label")
		printf '%s\n' "" "- Audit Result:" "  [+] PASS" "${a_output[@]}"
		return 0
	fi
}

audit_rule
exit $?
