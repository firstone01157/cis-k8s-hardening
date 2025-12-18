#!/bin/bash
# CIS Benchmark: 5.2.1
# Title: Ensure that the cluster has at least one active policy control mechanism in place
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 5.2.1..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	echo "[CMD] Executing: # Verify kubectl and jq are available"
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

	# Check all Namespaces for PodSecurityAdmission labels (enforce, warn, or audit)
	# Exclude system namespaces: kube-system, kube-public, kube-node-lease
	# Accept ANY of: enforce, warn, or audit labels (Safety First strategy)
	
	echo "[CMD] Executing: kubectl get ns -o json"
	ns_json=$(kubectl get ns -o json 2>/dev/null)
	
	echo "[CMD] Executing: jq filter for namespaces without valid PSS labels"
	
	# Step 1: Find namespaces with no PSS labels at all
	missing_all_labels=$(echo "$ns_json" | jq -r '.items[] | select(.metadata.name != "kube-system" and .metadata.name != "kube-public" and .metadata.name != "kube-node-lease") | select((.metadata.labels["pod-security.kubernetes.io/enforce"] == null) and (.metadata.labels["pod-security.kubernetes.io/warn"] == null) and (.metadata.labels["pod-security.kubernetes.io/audit"] == null)) | .metadata.name')
	
	# Step 2: Find namespaces with PSS labels but incorrect values (not "restricted" or "baseline")
	invalid_values=$(echo "$ns_json" | jq -r '.items[] | select(.metadata.name != "kube-system" and .metadata.name != "kube-public" and .metadata.name != "kube-node-lease") | select(((.metadata.labels["pod-security.kubernetes.io/enforce"] != null and .metadata.labels["pod-security.kubernetes.io/enforce"] != "restricted" and .metadata.labels["pod-security.kubernetes.io/enforce"] != "baseline")) or ((.metadata.labels["pod-security.kubernetes.io/warn"] != null and .metadata.labels["pod-security.kubernetes.io/warn"] != "restricted" and .metadata.labels["pod-security.kubernetes.io/warn"] != "baseline")) or ((.metadata.labels["pod-security.kubernetes.io/audit"] != null and .metadata.labels["pod-security.kubernetes.io/audit"] != "restricted" and .metadata.labels["pod-security.kubernetes.io/audit"] != "baseline"))) | .metadata.name')
	
	# Combine both lists
	missing_labels=$(echo -e "$missing_all_labels\n$invalid_values" | sort | uniq | grep -v '^$')

	if [ -n "$missing_labels" ]; then
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: The following namespaces are missing or have incorrect PSS labels:")
		echo "[FAIL_REASON] Check Failed: The following namespaces are missing or have incorrect PSS labels (enforce/warn/audit):"
		echo "[FIX_HINT] Run remediation script: 5.2.1_remediate.sh"
		while IFS= read -r ns; do
			[ -n "$ns" ] && a_output2+=(" - $ns")
		done <<< "$missing_labels"
		printf '%s\n' "" "- Audit Result:" "  [-] FAIL" " - Reason(s) for audit failure:" "${a_output2[@]}"
		return 1
	else
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: All non-system namespaces have valid PSS labels (enforce/warn/audit with value 'restricted' or 'baseline')")
		printf '%s\n' "" "- Audit Result:" "  [+] PASS" "${a_output[@]}"
		return 0
	fi
}

audit_rule
exit $?
