#!/bin/bash
# CIS Benchmark: 4.2.6
# Title: Ensure that the --make-iptables-util-chains argument is set to true (Automated)
# Level: • Level 1 - Worker Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	if ps -ef | grep kubelet | grep -v grep | grep -q "\--make-iptables-util-chains=true"; then
		a_output+=(" - Check Passed: --make-iptables-util-chains is set to true")
	else
		# Check config file
		config_file="/var/lib/kubelet/config.yaml"
		if [ -f "$config_file" ] && grep -q "makeIPTablesUtilChains: true" "$config_file"; then
			a_output+=(" - Check Passed: makeIPTablesUtilChains is set to true in $config_file")
		else
			a_output2+=(" - Check Failed: --make-iptables-util-chains is NOT set to true (Default is true, but explicit setting recommended)")
		fi
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
