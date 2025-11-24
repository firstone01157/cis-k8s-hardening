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
		l_missing=0
		if ! grep -q -- "--tls-cert-file" "$l_file"; then l_missing=1; fi
		if ! grep -q -- "--tls-private-key-file" "$l_file"; then l_missing=1; fi

		if [ "$l_missing" -eq 1 ]; then
			a_output2+=(" - Remediation Required: Please MANUALLY add '--tls-cert-file' and '--tls-private-key-file' to $l_file")
		else
			a_output+=(" - Remediation not needed: tls cert flags present")
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
