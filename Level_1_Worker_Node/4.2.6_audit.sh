#!/bin/bash
# CIS Benchmark: 4.2.6
# Title: Ensure that the --make-iptables-util-chains argument is set to true (Automated)
# Level: • Level 1 - Worker Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this command specifically
	## Description from CSV:
	## Run the following command on each node: ps -ef | grep kubelet Verify that if the --make-iptables-util-chains argument exists then it is set to true. If the --make-iptables-util-chains argument does no
	##
	## Command hint: Run the following command on each node: ps -ef | grep kubelet Verify that if the --make-iptables-util-chains argument exists then it is set to true. If the --make-iptables-util-chains argument does not exist, and there is a Kubelet config file specified by --config, verify that the file does not set makeIPTablesUtilChains to false.
	##
	## Placeholder logic (Fail by default until reviewed)
	## Change "1" to "0" once you implement the actual check

	if ps -ef | grep kubelet | grep -v grep | grep -q "\--make-iptables-util-chains=true"; then
		a_output+=(" - Check Passed: --make-iptables-util-chains is set to true")
	else
		a_output2+=(" - Check Failed: --make-iptables-util-chains is NOT set to true")
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
