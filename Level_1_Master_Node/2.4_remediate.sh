#!/bin/bash
# CIS Benchmark: 2.4
# Title: Ensure that the --peer-cert-file and --peer-key-file arguments are set as appropriate (Automated)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_file="/etc/kubernetes/manifests/etcd.yaml"
	if [ -e "$l_file" ]; then
		if grep -q "\--peer-cert-file" "$l_file" && grep -q "\--peer-key-file" "$l_file"; then
			a_output+=(" - Remediation not needed: etcd peer cert flags present in $l_file")
			return 0
		else
			a_output2+=(" - Remediation required: --peer-cert-file and/or --peer-key-file missing in $l_file. Please add them manually.")
			return 1
		fi
	else
		a_output+=(" - Remediation not needed: $l_file not found")
		return 0
	fi
}

remediate_rule
exit $?
