#!/bin/bash
# CIS Benchmark: 1.1.11
# Title: Ensure that the etcd data directory permissions are set to 700 or more restrictive (Automated)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this command specifically
	## Description from CSV:
	## On the etcd server node, get the etcd data directory, passed as an argument --data- dir, from the below command: ps -ef | grep etcd Run the below command (based on the etcd data directory found above)
	##
	## Command hint: (based on the etcd data directory found above). For example, stat -c %a /var/lib/etcd Verify that the permissions are 700 or more restrictive.
	##
	## Placeholder logic (Fail by default until reviewed)
	## Change "1" to "0" once you implement the actual check

	# Check if /var/lib/etcd exists
	if [ -d "/var/lib/etcd" ]; then
		l_mode=$(stat -c %a /var/lib/etcd)
		if [ "$l_mode" -le 700 ]; then
			a_output+=(" - Check Passed: Permissions on /var/lib/etcd are $l_mode")
		else
			a_output2+=(" - Check Failed: Permissions on /var/lib/etcd are $l_mode (should be 700 or more restrictive)")
		fi
	else
		a_output+=(" - Check Passed: /var/lib/etcd directory not found (assuming etcd not installed or different data dir)")
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
