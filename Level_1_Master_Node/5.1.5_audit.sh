#!/bin/bash
# CIS Benchmark: 5.1.5
# Title: Ensure that default service accounts are not actively used. (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# Get all pods using the default service account
	violations=$(kubectl get pods -A -o json 2>/dev/null | jq -r '.items[] | select(.spec.serviceAccountName == "default" or ((.spec.serviceAccountName | length) == 0)) | "\(.metadata.namespace)/\(.metadata.name)"' | sort -u)
	
	if [ -n "$violations" ]; then
		a_output2+=(" - Check Failed: Pods using default service account found:")
		while IFS= read -r line; do
			[ -n "$line" ] && a_output2+=(" - $line")
		done <<< "$violations"
	else
		a_output+=(" - Check Passed: No pods actively using default service account")
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
