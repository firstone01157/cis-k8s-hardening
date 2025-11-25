#!/bin/bash
# CIS Benchmark: 5.4.1
# Title: Prefer using secrets as files over secrets as environment variables (Manual)
# Level: • Level 2 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## Description from CSV:
	## Run the following command to find references to objects which use environment variables defined from secrets. kubectl get all -o jsonpath='{range .items[?(@..secretKeyRef)]} {.kind} {.metadata.name} {
	##
	## Command hint: Run the following command to find references to objects which use environment variables defined from secrets. kubectl get all -o jsonpath='{range .items[?(@..secretKeyRef)]} {.kind} {.metadata.name} {"\n"}{end}' -A
	##

	a_output+=(" - Manual Check: Prefer using secrets as files over secrets as environment variables.")
	a_output+=(" - Command: kubectl get all -o jsonpath='{range .items[?(@..secretKeyRef)]} {.kind} {.metadata.name} {\"\\n\"}{end}' -A")
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
