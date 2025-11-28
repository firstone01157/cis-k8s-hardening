#!/bin/bash
# CIS Benchmark: 5.6.1
# Title: Create administrative boundaries between resources using namespaces (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 5.6.1..."
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

	# Check that multiple namespaces exist beyond default ones (system, default, kube-public, kube-node-lease)
	echo "[CMD] Executing: kubectl get namespaces -o json"
	ns_json=$(kubectl get namespaces -o json 2>/dev/null)
	
	# Get total namespace count
	echo "[CMD] Executing: jq to count total namespaces"
	total_namespaces=$(echo "$ns_json" | jq '.items | length // 0')
	
	# Get count of non-system namespaces (exclude default system namespaces)
	echo "[CMD] Executing: jq to count non-system namespaces"
	non_system_namespaces=$(echo "$ns_json" | jq '[.items[] | select(.metadata.name | IN("default","kube-system","kube-public","kube-node-lease") | not)] | length // 0')
	
	if [ -z "$total_namespaces" ]; then
		total_namespaces=0
	fi
	if [ -z "$non_system_namespaces" ]; then
		non_system_namespaces=0
	fi
	
	if [ "$non_system_namespaces" -gt 0 ]; then
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: Administrative boundaries using namespaces are in place")
		a_output+=(" - Total namespaces: $total_namespaces")
		a_output+=(" - Custom namespaces (excluding system): $non_system_namespaces")
		printf '%s\n' "" "- Audit Result:" "  [+] PASS" "${a_output[@]}"
		return 0
	else
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: No custom administrative boundaries found")
		echo "[FAIL_REASON] Check Failed: No custom administrative boundaries found"
		echo "[FIX_HINT] Run remediation script: 5.6.1_remediate.sh"
		a_output2+=(" - Only system namespaces exist. Create custom namespaces for workload isolation.")
		printf '%s\n' "" "- Audit Result:" "  [-] FAIL" " - Reason(s) for audit failure:" "${a_output2[@]}"
		return 1
	fi
}

audit_rule
exit $?
