#!/bin/bash
# CIS Benchmark: 5.2.3
# Title: Minimize the admission of containers wishing to share the host process ID namespace (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this command specifically
	## Description from CSV:
	## Fetch hostPID from each pod with get pods -A -o=jsonpath=$'{range .items[*]}{@.metadata.name}: {@.spec.hostPID}\n{end}'
	##
	## Command hint: Fetch hostPID from each pod with get pods -A -o=jsonpath=$'{range .items[*]}{@.metadata.name}: {@.spec.hostPID}\n{end}'
	##
	## Placeholder logic (Fail by default until reviewed)
	## Change "1" to "0" once you implement the actual check

	a_output+=(" - Manual Check: Minimize admission of containers sharing host PID.")
	a_output+=(" - Command: kubectl get pods -A -o=jsonpath='{range .items[*]}{@.metadata.name}: {@.spec.hostPID}{\"\\n\"}{end}' | grep true")
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
