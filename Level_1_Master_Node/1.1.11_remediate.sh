#!/bin/bash
# CIS Benchmark: 1.1.11
# Title: Ensure that the etcd data directory permissions are set to 700 or more restrictive (Automated)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_dir="/var/lib/etcd"
	if [ -d "$l_dir" ]; then
		l_mode=$(stat -c %a "$l_dir")
		if [ "$l_mode" -le 700 ]; then
			a_output+=(" - Remediation not needed: Permissions on $l_dir are $l_mode")
			return 0
		else
			chmod 700 "$l_dir"
			l_mode_new=$(stat -c %a "$l_dir")
			if [ "$l_mode_new" -le 700 ]; then
				a_output+=(" - Remediation applied: Permissions on $l_dir changed to $l_mode_new")
				return 0
			else
				a_output2+=(" - Remediation failed: Could not change permissions on $l_dir")
				return 1
			fi
		fi
	else
		a_output+=(" - Remediation not needed: $l_dir not found")
		return 0
	fi
}

remediate_rule
exit $?
