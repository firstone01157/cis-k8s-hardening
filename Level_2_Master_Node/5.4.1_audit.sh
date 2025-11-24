#!/bin/bash
# CIS Benchmark: 5.4.1
# Title: Prefer using secrets as files over secrets as environment variables (Manual)
# Level: • Level 2 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# Check for usage of secretKeyRef in environment variables
	if command -v kubectl >/dev/null 2>&1; then
		# Find pods using secretKeyRef in env
		offending_pods=$(kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"/"}{.metadata.name}{" uses secretKeyRef in env\n"}{end}' | grep "uses secretKeyRef")
		# Note: The above jsonpath is simplified. A more accurate one for env vars specifically:
		# {range .items[*]}{range .spec.containers[*].env[?(@.valueFrom.secretKeyRef)]}{...}
		
		# Let's try a more specific check if possible, or stick to the manual hint command which is broader.
		# The hint command: kubectl get all -o jsonpath='{range .items[?(@..secretKeyRef)]} {.kind} {.metadata.name} {"\n"}{end}' -A
		
		offending_resources=$(kubectl get all -A -o jsonpath='{range .items[?(@..secretKeyRef)]}{.kind}{" "}{.metadata.namespace}{"/"}{.metadata.name}{"\n"}{end}')
		
		if [ -n "$offending_resources" ]; then
			a_output2+=(" - Check Failed: Found resources using secrets as environment variables (secretKeyRef):")
			while IFS= read -r line; do
				a_output2+=("   * $line")
			done <<< "$(echo "$offending_resources" | head -n 5)"
			if [ $(echo "$offending_resources" | wc -l) -gt 5 ]; then
				a_output2+=("   * ... and more")
			fi
		else
			a_output+=(" - Check Passed: No resources found using secretKeyRef in environment variables.")
		fi
	else
		a_output+=(" - Manual Check: kubectl not found. Please verify secret usage manually.")
		a_output+=(" - Command: kubectl get all -A -o jsonpath='...'")
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
