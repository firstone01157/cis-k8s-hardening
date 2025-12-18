#!/bin/bash
# CIS Benchmark: 5.1.1
# Title: Ensure that the cluster-admin role is only used where required
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 5.1.1..."
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

	# Verify cluster is reachable
	echo "[CMD] Executing: if ! kubectl cluster-info &>/dev/null; then"
	if ! kubectl cluster-info &>/dev/null; then
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Error: Unable to connect to Kubernetes cluster")
		echo "[FAIL_REASON] Check Error: Unable to connect to Kubernetes cluster"
		echo "[FIX_HINT] Check kubeconfig and cluster connectivity."
		printf '%s\n' "" "- Audit Result:" "  [-] ERROR" "${a_output2[@]}"
		return 2
	fi

	# Get all cluster role bindings that reference cluster-admin
	# Filter out system components (system:*, kubeadm:*)
	echo "[CMD] Executing: kubectl get clusterrolebindings -o json | jq to filter cluster-admin bindings excluding system subjects"
	admin_bindings=$(kubectl get clusterrolebindings -o json 2>/dev/null | jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.name as $binding | (.subjects[]? | select(.name | startswith("system:") or startswith("kubeadm:") | not)) | "\($binding)|\(.kind):\(.name)"')
	
	count=0
	if [ -n "$admin_bindings" ]; then
		while IFS='|' read -r binding_name subject; do
			[ -z "$binding_name" ] && continue
			((count++))
			# Log details for failure context
			if [ "$count" -gt 1 ]; then
				a_output2+=(" - Binding '$binding_name' grants cluster-admin to $subject")
			fi
		done <<< "$admin_bindings"
	fi

	if [ "$count" -gt 1 ]; then
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: Found $count non-system cluster-admin bindings (Limit: 1)")
		echo "[FAIL_REASON] Check Failed: Found $count non-system cluster-admin bindings (Limit: 1)"
		echo "[FIX_HINT] Run remediation script: 5.1.1_remediate.sh"
		printf '%s\n' "" "- Audit Result:" "  [-] FAIL" " - Reason(s) for audit failure:" "${a_output2[@]}"
		return 1
	else
		if [ "$count" -eq 1 ]; then
			echo "[INFO] Check Passed"
			a_output+=(" - Note: 1 non-system cluster-admin binding found (Acceptable)")
		else
			echo "[INFO] Check Passed"
			a_output+=(" - Check Passed: No non-system cluster-admin bindings found")
		fi
		printf '%s\n' "" "- Audit Result:" "  [+] PASS" "${a_output[@]}"
		return 0
	fi
}

audit_rule
exit $?
