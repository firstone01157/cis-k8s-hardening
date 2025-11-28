#!/bin/bash
# CIS Benchmark: 1.2.26
# Title: Ensure that the --etcd-cafile argument is set as appropriate
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

		if grep -q -- "--etcd-cafile" "$l_file"; then
			:
		else
			sed -i "/- kube-apiserver/a \    - --etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt" "$l_file"
			a_output+=(" - Remediation applied: Inserted --etcd-cafile in $l_file")
		fi
		return 0
	else
		a_output+=(" - Remediation not needed: $l_file not found")
		return 0
	fi
}

remediate_rule
exit $?
