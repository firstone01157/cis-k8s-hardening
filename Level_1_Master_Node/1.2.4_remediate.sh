#!/bin/bash
# CIS Benchmark: 1.2.4
# Title: Ensure that the --kubelet-client-certificate and --kubelet-client-key arguments are set as appropriate (Automated)
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
		if ! grep -q "\--kubelet-client-certificate" "$l_file"; then
			l_missing=1
		fi
		if ! grep -q "\--kubelet-client-key" "$l_file"; then
			l_missing=1
		fi
		if [ "$l_missing" -eq 1 ]; then
			a_output2+=(" - Remediation required: --kubelet-client-certificate and/or --kubelet-client-key missing in $l_file. Please add them manually with correct paths.")
		else
			a_output+=(" - Remediation not needed: flags are present in $l_file")
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
