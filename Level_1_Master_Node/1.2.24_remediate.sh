#!/bin/bash
# CIS Benchmark: 1.2.24
# Title: Ensure that the --tls-cert-file and --tls-private-key-file arguments are set as appropriate (Automated)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_file="/etc/kubernetes/manifests/kube-apiserver.yaml"
	if [ -e "$l_file" ]; then
		if grep -q "\--tls-cert-file" "$l_file" && grep -q "\--tls-private-key-file" "$l_file"; then
			a_output+=(" - Remediation not needed: TLS cert flags present in $l_file")
			return 0
		else
			a_output2+=(" - Remediation required: --tls-cert-file and/or --tls-private-key-file missing in $l_file. Please add them manually.")
			return 1
		fi
	else
		a_output+=(" - Remediation not needed: $l_file not found")
	fi

	if [ "${#a_output2[@]}" -le 0 ]; then
		return 0
	else
		return 1
	fi
}

remediate_rule
exit $?
