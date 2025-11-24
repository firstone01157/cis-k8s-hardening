#!/bin/bash
# CIS Benchmark: 1.1.8
# Title: Ensure that the etcd pod specification file ownership is set to root:root (Automated)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_file="/etc/kubernetes/manifests/etcd.yaml"
	if [ -e "$l_file" ]; then
		l_owner=$(stat -c %U:%G "$l_file")
		if [ "$l_owner" == "root:root" ]; then
			a_output+=(" - Remediation not needed: Ownership on $l_file is $l_owner")
			return 0
		else
			chown root:root "$l_file"
			l_owner_new=$(stat -c %U:%G "$l_file")
			if [ "$l_owner_new" == "root:root" ]; then
				a_output+=(" - Remediation applied: Ownership on $l_file changed to $l_owner_new")
				return 0
			else
				a_output2+=(" - Remediation failed: Could not change ownership on $l_file")
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
