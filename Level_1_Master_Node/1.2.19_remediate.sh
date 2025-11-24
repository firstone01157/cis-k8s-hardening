#!/bin/bash
# CIS Benchmark: 1.2.19
# Title: Ensure that the --audit-log-maxsize argument is set to 100 or as appropriate (Automated)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_file="/etc/kubernetes/manifests/kube-apiserver.yaml"
	if [ -e "$l_file" ]; then
		if grep -q -- "--audit-log-maxsize" "$l_file"; then
			a_output+=(" - Remediation not needed: --audit-log-maxsize is present")
		else
			a_output2+=(" - Remediation Required: Please MANUALLY add '--audit-log-maxsize=100' to $l_file")
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
