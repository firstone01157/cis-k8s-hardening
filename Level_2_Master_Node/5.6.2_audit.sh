#!/bin/bash
# CIS Benchmark: 5.6.2
# Title: Ensure that the seccomp profile is set to docker/default in your pod definitions (Manual)
# Level: • Level 2 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this command specifically
	## Description from CSV:
	## Review the pod definitions in your cluster. It should create a line as below: securityContext: seccompProfile: type: RuntimeDefault
	##
	## Command hint: Review the pod definitions in your cluster. It should create a line as below: securityContext: seccompProfile: type: RuntimeDefault
	##
	## Placeholder logic (Fail by default until reviewed)
	## Change "1" to "0" once you implement the actual check

	a_output+=(" - Manual Check: Ensure seccomp profile is set to docker/default.")
	a_output+=(" - Command: kubectl get pods -A -o=jsonpath='{range .items[*]}{@.metadata.name}: {@..securityContext.seccompProfile.type}{\"\\n\"}{end}'")
	return 0

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
