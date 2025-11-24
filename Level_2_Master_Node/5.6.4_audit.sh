#!/bin/bash
# CIS Benchmark: 5.6.4
# Title: The default namespace should not be used (Manual)
# Level: • Level 2 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# Check for resources in default namespace (excluding system service 'kubernetes')
	if command -v kubectl >/dev/null 2>&1; then
		# Get all resources in default namespace
		resources=$(kubectl get all -n default --ignore-not-found -o name | grep -v "service/kubernetes")
		
		if [ -n "$resources" ]; then
			a_output2+=(" - Check Failed: Found user resources in 'default' namespace:")
			while IFS= read -r line; do
				a_output2+=("   * $line")
			done <<< "$(echo "$resources" | head -n 5)"
			if [ $(echo "$resources" | wc -l) -gt 5 ]; then
				a_output2+=("   * ... and more")
			fi
		else
			a_output+=(" - Check Passed: No user resources found in 'default' namespace.")
		fi
	else
		a_output+=(" - Manual Check: kubectl not found. Please verify default namespace usage manually.")
		a_output+=(" - Command: kubectl get all -n default")
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
