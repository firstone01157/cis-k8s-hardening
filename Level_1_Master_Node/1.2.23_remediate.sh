#!/bin/bash
# CIS Benchmark: 1.2.23
# Title: Ensure that the --etcd-certfile and --etcd-keyfile arguments are set as appropriate
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

		if grep -q -- "--etcd-certfile" "$l_file"; then
			:
		else
			sed -i "/- kube-apiserver/a \    - --etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt" "$l_file"
			a_output+=(" - Remediation applied: Inserted --etcd-certfile in $l_file")
		fi

		if grep -q -- "--etcd-keyfile" "$l_file"; then
			:
		else
			sed -i "/- kube-apiserver/a \    - --etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key" "$l_file"
			a_output+=(" - Remediation applied: Inserted --etcd-keyfile in $l_file")
		fi
		return 0
	else
		a_output+=(" - Remediation not needed: $l_file not found")
		return 0
	fi
}

remediate_rule
exit $?
