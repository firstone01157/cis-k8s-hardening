#!/bin/bash
# CIS Benchmark: 1.2.29
# Title: Ensure that the API Server only makes use of Strong Cryptographic Ciphers (Manual)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_file="/etc/kubernetes/manifests/kube-apiserver.yaml"
	if [ -e "$l_file" ]; then
		if grep -q -- "--tls-cipher-suites" "$l_file"; then
			a_output+=(" - Remediation not needed: --tls-cipher-suites is present")
		else
			a_output2+=(" - Remediation Required: Please MANUALLY add '--tls-cipher-suites=...' to $l_file")
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
