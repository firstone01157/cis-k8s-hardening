#!/bin/bash
# CIS Benchmark: 4.2.14
# Title: Ensure that the --seccomp-default parameter is set to true (Manual)
# Level: • Level 1 - Worker Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## Description from CSV:
	## Review the Kubelet's start-up parameters for the value of --seccomp-default, and check the Kubelet configuration file for the seccompDefault . If neither of these values is set, then the seccomp profi
	##
	## Command hint: Review the Kubelet's start-up parameters for the value of --seccomp-default, and check the Kubelet configuration file for the seccompDefault . If neither of these values is set, then the seccomp profile is not in use.
	##

	if ps -ef | grep kubelet | grep -v grep | grep -q "\--seccomp-default=true"; then
		a_output+=(" - Check Passed: --seccomp-default is set to true")
	else
		a_output2+=(" - Check Failed: --seccomp-default is NOT set to true")
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
