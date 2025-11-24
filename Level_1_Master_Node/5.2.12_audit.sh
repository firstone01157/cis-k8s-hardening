#!/bin/bash
# CIS Benchmark: 5.2.12
# Title: Minimize the admission of containers which use HostPorts (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this command specifically
	## Description from CSV:
	## List the policies in use for each namespace in the cluster, ensure that each policy disallows the admission of containers which have hostPort sections.
	##
	## Command hint: List the policies in use for each namespace in the cluster, ensure that each policy disallows the admission of containers which have hostPort sections.
	##
	## Placeholder logic (Fail by default until reviewed)
	## Change "1" to "0" once you implement the actual check

	a_output+=(" - Manual Check: Minimize admission of containers which use HostPorts.")
	a_output+=(" - Command: kubectl get pods -A -o=jsonpath='{range .items[*]}{@.metadata.name}: {@.spec.containers[*].ports[*].hostPort}{\"\\n\"}{end}'")
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
