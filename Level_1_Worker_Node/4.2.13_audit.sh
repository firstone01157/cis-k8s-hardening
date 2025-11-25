#!/bin/bash
# CIS Benchmark: 4.2.13
# Title: Ensure that a limit is set on pod PIDs (Manual)
# Level: • Level 1 - Worker Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## Description from CSV:
	## Review the Kubelet's start-up parameters for the value of --pod-max-pids, and check the Kubelet configuration file for the PodPidsLimit . If neither of these values is set, then there is no limit in p
	##
	## Command hint: Review the Kubelet's start-up parameters for the value of --pod-max-pids, and check the Kubelet configuration file for the PodPidsLimit . If neither of these values is set, then there is no limit in place.
	##

	if ps -ef | grep kubelet | grep -v grep | grep -q "\--pod-max-pids"; then
		a_output+=(" - Check Passed: --pod-max-pids is set")
	else
		a_output2+=(" - Check Failed: --pod-max-pids is NOT set")
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
