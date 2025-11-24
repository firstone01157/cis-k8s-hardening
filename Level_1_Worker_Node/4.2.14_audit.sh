#!/bin/bash
# CIS Benchmark: 4.2.14
# Title: Ensure that the --seccomp-default parameter is set to true (Manual)
# Level: • Level 1 - Worker Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	if ps -ef | grep kubelet | grep -v grep | grep -q "\--seccomp-default=true"; then
		a_output+=(" - Check Passed: --seccomp-default is set to true")
	else
		# Check config file
		config_file="/var/lib/kubelet/config.yaml"
		if [ -f "$config_file" ] && grep -q "seccompDefault: true" "$config_file"; then
			a_output+=(" - Check Passed: seccompDefault is set to true in $config_file")
		else
			a_output2+=(" - Check Failed: --seccomp-default is NOT set to true")
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
