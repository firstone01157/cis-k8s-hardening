#!/bin/bash
# CIS Benchmark: 4.2.7
# Title: Ensure that the --hostname-override argument is not set (Manual)
# Level: • Level 1 - Worker Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this command specifically
	## Description from CSV:
	## Run the following command on each node: ps -ef | grep kubelet Verify that --hostname-override argument does not exist. Note This setting is not configurable via the Kubelet config file.
	##
	## Command hint: Run the following command on each node: ps -ef | grep kubelet Verify that --hostname-override argument does not exist. Note This setting is not configurable via the Kubelet config file.
	##
	## Placeholder logic (Fail by default until reviewed)
	## Change "1" to "0" once you implement the actual check

	if ps -ef | grep kubelet | grep -v grep | grep -q "\--hostname-override"; then
		a_output2+=(" - Check Failed: --hostname-override is set")
	else
		a_output+=(" - Check Passed: --hostname-override is NOT set")
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
