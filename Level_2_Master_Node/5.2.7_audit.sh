#!/bin/bash
# CIS Benchmark: 5.2.7
# Title: Minimize the admission of root containers (Manual)
# Level: • Level 2 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# Check for pods that do not have runAsNonRoot set to true
	# This is a heuristic check.
	if command -v kubectl >/dev/null 2>&1; then
		offending_pods=$(kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"/"}{.metadata.name}{" runAsNonRoot:"}{.spec.securityContext.runAsNonRoot}{" "}{.spec.containers[*].securityContext.runAsNonRoot}{"\n"}{end}' | grep -v "true")
		
		if [ -n "$offending_pods" ]; then
			a_output2+=(" - Check Failed: Found pods that may be running as root (runAsNonRoot != true):")
			# Limit output to first 5 to avoid spamming
			while IFS= read -r line; do
				a_output2+=("   * $line")
			done <<< "$(echo "$offending_pods" | head -n 5)"
			if [ $(echo "$offending_pods" | wc -l) -gt 5 ]; then
				a_output2+=("   * ... and more")
			fi
		else
			a_output+=(" - Check Passed: All checked pods appear to have runAsNonRoot set to true (or kubectl output was clean)")
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
