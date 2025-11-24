#!/bin/bash
# CIS Benchmark: 1.1.15
# Title: Ensure that the scheduler.conf file permissions are set to 600 or more restrictive (Automated)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_file="/etc/kubernetes/scheduler.conf"
	if [ -e "$l_file" ]; then
		l_mode=$(stat -c %a "$l_file")
		if [ "$l_mode" -le 600 ]; then
			a_output+=(" - Check Passed: Permissions on $l_file are $l_mode")
		else
			a_output2+=(" - Check Failed: Permissions on $l_file are $l_mode (should be 600 or more restrictive)")
		fi
	else
		a_output+=(" - Check Passed: $l_file not found")
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
