#!/bin/bash
# CIS Benchmark: 1.2.20
# Title: Ensure that the --request-timeout argument is set as appropriate (Manual)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# Manual check, remediation is only if needed.
    a_output+=(" - Remediation not needed: This is a manual check. If you need to change timeout, edit /etc/kubernetes/manifests/kube-apiserver.yaml manually.")

	if [ "${#a_output2[@]}" -le 0 ]; then
		return 0
	else
		return 1
	fi
}

remediate_rule
exit $?
