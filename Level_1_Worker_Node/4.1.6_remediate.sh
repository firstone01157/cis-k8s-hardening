#!/bin/bash
# CIS Benchmark: 4.1.6
# Title: Ensure that the --kubeconfig kubelet.conf file ownership is set to root:root
# Level: Level 1 - Worker Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_file="/etc/kubernetes/kubelet.conf"
	if [ ! -e "$l_file" ]; then
		l_file=$(ps -ef | grep kubelet | grep -- --kubeconfig | sed 's/.*--kubeconfig[= ]\([^ ]*\).*/\1/')
	fi

	if [ -e "$l_file" ]; then
		l_owner=$(stat -c "%U:%G" "$l_file")
		if [ "$l_owner" = "root:root" ]; then
			a_output+=(" - Remediation not needed: Ownership on $l_file is $l_owner")
			return 0
		else
			cp -p "$l_file" "$l_file.bak.$(date +%s)"
			chown root:root "$l_file"
			l_owner_new=$(stat -c "%U:%G" "$l_file")
			if [ "$l_owner_new" = "root:root" ]; then
				a_output+=(" - Remediation applied: Ownership on $l_file changed to $l_owner_new")
				return 0
			else
				a_output2+=(" - Remediation failed: Could not change ownership on $l_file")
				return 1
			fi
		fi
	else
		a_output+=(" - Remediation not needed: kubelet.conf file not found")
		return 0
	fi
}

remediate_rule
exit $?
