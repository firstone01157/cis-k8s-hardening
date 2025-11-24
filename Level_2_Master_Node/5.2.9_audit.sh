#!/bin/bash
# CIS Benchmark: 5.2.9
# Title: Minimize the admission of containers with capabilities assigned (Manual)
# Level: • Level 2 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# Check for pods that do not drop all capabilities or add capabilities
	if command -v kubectl >/dev/null 2>&1; then
		# This is a broad check. Ideally we want to see 'drop: ["ALL"]'
		offending_pods=$(kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"/"}{.metadata.name}{" Capabilities:"}{.spec.containers[*].securityContext.capabilities}{"\n"}{end}' | grep -v '"drop":\["ALL"\]')
		
		if [ -n "$offending_pods" ]; then
			a_output2+=(" - Check Failed: Found pods that might not be dropping ALL capabilities:")
			while IFS= read -r line; do
				a_output2+=("   * $line")
			done <<< "$(echo "$offending_pods" | head -n 5)"
			if [ $(echo "$offending_pods" | wc -l) -gt 5 ]; then
				a_output2+=("   * ... and more")
			fi
		else
			a_output+=(" - Check Passed: All checked pods appear to drop ALL capabilities (or output clean)")
		fi
	else
		a_output+=(" - Manual Check: kubectl not found. Please verify policies manually.")
		a_output+=(" - Command: kubectl get pods -A -o jsonpath='...'")
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
