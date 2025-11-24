#!/bin/bash
# CIS Benchmark: 5.6.2
# Title: Ensure that the seccomp profile is set to docker/default in your pod definitions (Manual)
# Level: • Level 2 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# Check for pods without seccompProfile set to RuntimeDefault or localhost
	if command -v kubectl >/dev/null 2>&1; then
		# This check looks for pods where seccompProfile.type is NOT RuntimeDefault or Localhost
		# Note: This is a strict check.
		offending_pods=$(kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"/"}{.metadata.name}{" seccomp:"}{.spec.securityContext.seccompProfile.type}{" "}{.spec.containers[*].securityContext.seccompProfile.type}{"\n"}{end}' | grep -v -E "RuntimeDefault|Localhost")
		
		if [ -n "$offending_pods" ]; then
			a_output2+=(" - Check Failed: Found pods without 'RuntimeDefault' or 'Localhost' seccomp profile:")
			while IFS= read -r line; do
				a_output2+=("   * $line")
			done <<< "$(echo "$offending_pods" | head -n 5)"
			if [ $(echo "$offending_pods" | wc -l) -gt 5 ]; then
				a_output2+=("   * ... and more")
			fi
		else
			a_output+=(" - Check Passed: All checked pods appear to have a valid seccomp profile.")
		fi
	else
		a_output+=(" - Manual Check: kubectl not found. Please verify seccomp profiles manually.")
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
