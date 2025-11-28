#!/bin/bash
# CIS Benchmark: 1.2.22
# Title: Ensure that the --service-account-key-file argument is set as appropriate
# Level: Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_file="/etc/kubernetes/manifests/kube-apiserver.yaml"
	if [ -e "$l_file" ]; then
		# Backup
		cp "$l_file" "$l_file.bak_$(date +%s)"

		if grep -q -- "--service-account-key-file" "$l_file"; then
			:
		else
			# Default path
			sed -i "/- kube-apiserver/a \    - --service-account-key-file=/etc/kubernetes/pki/sa.pub" "$l_file"
			a_output+=(" - Remediation applied: Inserted --service-account-key-file in $l_file")
		fi
		return 0
	else
		a_output+=(" - Remediation not needed: $l_file not found")
		return 0
	fi
}

remediate_rule
exit $?
