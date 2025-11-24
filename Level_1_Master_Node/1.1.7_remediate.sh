#!/bin/bash
# CIS Benchmark: 1.1.7
# Title: Ensure that the etcd pod specification file permissions are set to 600 or more restrictive (Automated)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_file="/etc/kubernetes/manifests/etcd.yaml"
	if [ -e "$l_file" ]; then
		l_mode=$(stat -c %a "$l_file")
		if [ "$l_mode" -le 600 ]; then
			a_output+=(" - Remediation not needed: Permissions on $l_file are $l_mode")
			return 0
		else
			chmod 600 "$l_file"
			l_mode_new=$(stat -c %a "$l_file")
			if [ "$l_mode_new" -le 600 ]; then
				a_output+=(" - Remediation applied: Permissions on $l_file changed to $l_mode_new")
				return 0
			else
				a_output2+=(" - Remediation failed: Could not change permissions on $l_file")
				return 1
			fi
		fi
	else
		a_output+=(" - Remediation not needed: $l_file not found")
		return 0
	fi
}

remediate_rule
exit $?
