#!/bin/bash
# CIS Benchmark: 4.2.4
# Title: Verify that if defined, readOnlyPort is set to 0 (Manual)
# Level: • Level 1 - Worker Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this command specifically
	## Description from CSV:
	## Run the following command on each node: ps -ef | grep kubelet Verify that the --read-only-port argument exists and is set to 0. If the --read-only-port argument is not present, check that there is a K
	##
	## Command hint: Run the following command on each node: ps -ef | grep kubelet Verify that the --read-only-port argument exists and is set to 0. If the --read-only-port argument is not present, check that there is a Kubelet config file specified by --config. Check that if there is a readOnlyPort entry in the file, it is set to 0.
	##
	## Placeholder logic (Fail by default until reviewed)
	## Change "1" to "0" once you implement the actual check

	if ps -ef | grep kubelet | grep -v grep | grep -q "\--read-only-port=0"; then
		a_output+=(" - Check Passed: --read-only-port is set to 0")
	else
		a_output2+=(" - Check Failed: --read-only-port is NOT set to 0")
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
