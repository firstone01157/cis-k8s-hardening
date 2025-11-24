#!/bin/bash
# CIS Benchmark: 5.3.2
# Title: Ensure that all Namespaces have Network Policies defined (Manual)
# Level: • Level 2 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# Check which namespaces do NOT have any NetworkPolicy
	if command -v kubectl >/dev/null 2>&1; then
		# Get list of all namespaces
		namespaces=$(kubectl get ns -o jsonpath='{.items[*].metadata.name}')
		
		missing_policies=""
		for ns in $namespaces; do
			# Check if there are any network policies in this namespace
			np_count=$(kubectl get netpol -n "$ns" --no-headers 2>/dev/null | wc -l)
			if [ "$np_count" -eq 0 ]; then
				missing_policies+="$ns "
			fi
		done

		if [ -n "$missing_policies" ]; then
			a_output2+=(" - Check Failed: The following namespaces have NO Network Policies defined:")
			for ns in $missing_policies; do
				a_output2+=("   * $ns")
			done
		else
			a_output+=(" - Check Passed: All namespaces have at least one Network Policy.")
		fi
	else
		a_output+=(" - Manual Check: kubectl not found. Please verify NetworkPolicies manually.")
		a_output+=(" - Command: kubectl get netpol -A")
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
