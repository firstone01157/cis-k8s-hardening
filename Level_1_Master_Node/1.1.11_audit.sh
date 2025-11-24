#!/bin/bash
# CIS Benchmark: 1.1.11
# Title: Ensure that the etcd data directory permissions are set to 700 or more restrictive (Automated)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_dir="/var/lib/etcd"
	if [ -d "$l_dir" ]; then
		l_mode=$(stat -c %a "$l_dir")
		if [ "$l_mode" -le 700 ]; then
			a_output+=(" - Check Passed: Permissions on $l_dir are $l_mode")
		else
			a_output2+=(" - Check Failed: Permissions on $l_dir are $l_mode (should be 700 or more restrictive)")
		fi
	else
		a_output+=(" - Check Passed: $l_dir directory not found (assuming etcd not installed or different data dir)")
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
