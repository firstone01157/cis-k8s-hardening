#!/bin/bash
# CIS Benchmark: 4.2.5
# Title: Ensure that the --streaming-connection-idle-timeout argument is not set to 0 (Manual)
# Level: • Level 1 - Worker Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	if ps -ef | grep kubelet | grep -v grep | grep -q "\--streaming-connection-idle-timeout=0"; then
		a_output2+=(" - Check Failed: --streaming-connection-idle-timeout is set to 0")
	else
		a_output+=(" - Check Passed: --streaming-connection-idle-timeout is NOT set to 0")
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
