#!/bin/bash
# CIS Benchmark: 5.1.1
# Title: Ensure that the cluster-admin role is only used where required (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# Verify kubectl is available
	if ! command -v kubectl &> /dev/null; then
		a_output2+=(" - Check Error: kubectl command not found")
		printf '%s\n' "" "- Audit Result:" "  [-] ERROR" "${a_output2[@]}"
		return 2
	fi

	# Verify cluster is reachable
	if ! kubectl cluster-info &>/dev/null; then
		a_output2+=(" - Check Error: Unable to connect to Kubernetes cluster")
		printf '%s\n' "" "- Audit Result:" "  [-] ERROR" "${a_output2[@]}"
		return 2
	fi

	# Get all cluster role bindings that reference cluster-admin using proper jq parsing
	# Streams output to avoid temp files and memory issues
	kubectl get clusterrolebindings -o json 2>/dev/null | jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.name as $binding | .subjects[]? // empty | "\($binding)|\(.kind // "")|\(.name // "")"' | \
	while IFS='|' read -r binding_name subject_kind subject_name; do
		[ -z "$binding_name" ] && continue
		
		# Flag non-system subjects with cluster-admin
		# Safe subjects: system:*, kubeadm:*, kube:* prefixes
		if [[ ! "$subject_name" =~ ^(system:|kubeadm:|kube:) ]] && [[ -n "$subject_name" ]]; then
			a_output2+=(" - Binding '$binding_name' grants cluster-admin to $subject_kind:$subject_name")
		fi
	done
	
	if [ ${#a_output2[@]} -eq 0 ]; then
		a_output+=(" - Check Passed: Only system accounts have cluster-admin role bindings")
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
