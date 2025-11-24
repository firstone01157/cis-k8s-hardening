#!/bin/bash
# CIS Benchmark: 1.1.12
# Title: Ensure that the etcd data directory ownership is set to etcd:etcd (Automated)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_dir="/var/lib/etcd"
	if [ -d "$l_dir" ]; then
		l_owner=$(stat -c %U:%G "$l_dir")
		if [ "$l_owner" == "etcd:etcd" ]; then
			a_output+=(" - Remediation not needed: Ownership on $l_dir is $l_owner")
			return 0
		else
			chown etcd:etcd "$l_dir"
			l_owner_new=$(stat -c %U:%G "$l_dir")
			if [ "$l_owner_new" == "etcd:etcd" ]; then
				a_output+=(" - Remediation applied: Ownership on $l_dir changed to $l_owner_new")
				return 0
			else
				a_output2+=(" - Remediation failed: Could not change ownership on $l_dir")
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
