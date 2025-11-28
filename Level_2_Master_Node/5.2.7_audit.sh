#!/bin/bash
# CIS Benchmark: 5.2.7
# Title: Minimize the admission of root containers (Automated)
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 5.2.7..."
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
		echo "[FIX_HINT] Run remediation script: 5.2.7_remediate.sh"
		printf '%s\n' "" "- Audit Result:" "  [-] ERROR" "${a_output2[@]}"
		return 2
	fi

	# Check for pods running as root (runAsNonRoot != true)
	# Exclude system namespaces
	echo "[CMD] Executing: root_pods=$(kubectl get pods -A -o json 2>/dev/null | jq -r \'.items[] | select(.metadata.namespace | test(\"^(kube-system|kube-public|kube-node-lease)$\") | not) | select((.spec.securityContext.runAsNonRoot != true) and (.spec.containers[]?.securityContext.runAsNonRoot != true)) | \"\\(.metadata.namespace)/\\(.metadata.name)\"\' | sort -u)"
	root_pods=$(kubectl get pods -A -o json 2>/dev/null | jq -r '.items[] | select(.metadata.namespace | test("^(kube-system|kube-public|kube-node-lease)$") | not) | select((.spec.securityContext.runAsNonRoot != true) and (.spec.containers[]?.securityContext.runAsNonRoot != true)) | "\(.metadata.namespace)/\(.metadata.name)"' | sort -u)
	
	if [ -z "$root_pods" ]; then
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: No pods running as root found")
	else
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: Found pods running as root:")
		echo "[FAIL_REASON] Check Failed: Found pods running as root:"
		echo "[FIX_HINT] Run remediation script: 5.2.7_remediate.sh"
		while IFS= read -r pod; do
			echo "[INFO] Check Failed"
			a_output2+=(" - Pod: $pod")
			echo "[FAIL_REASON] Pod: $pod"
			echo "[FIX_HINT] Run remediation script: 5.2.7_remediate.sh"
		done <<< "$root_pods"
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
