#!/bin/bash
# CIS Benchmark: 1.2.24
# Title: Ensure that the --tls-cert-file and --tls-private-key-file arguments are set as appropriate
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

		if grep -q -- "--tls-cert-file" "$l_file"; then
			:
		else
			sed -i "/- kube-apiserver/a \    - --tls-cert-file=/etc/kubernetes/pki/apiserver.crt" "$l_file"
			a_output+=(" - Remediation applied: Inserted --tls-cert-file in $l_file")
		fi

		if grep -q -- "--tls-private-key-file" "$l_file"; then
			:
		else
			sed -i "/- kube-apiserver/a \    - --tls-private-key-file=/etc/kubernetes/pki/apiserver.key" "$l_file"
			a_output+=(" - Remediation applied: Inserted --tls-private-key-file in $l_file")
		fi
		return 0
	else
		a_output+=(" - Remediation not needed: $l_file not found")
		return 0
	fi
}

remediate_rule
exit $?
