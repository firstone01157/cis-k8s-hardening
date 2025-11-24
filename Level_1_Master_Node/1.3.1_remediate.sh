#!/bin/bash
# CIS Benchmark: 1.3.1
# Title: Ensure that the --terminated-pod-gc-threshold argument is set as appropriate (Manual)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_file="/etc/kubernetes/manifests/kube-controller-manager.yaml"
	if [ -e "$l_file" ]; then
		if grep -q -- "--terminated-pod-gc-threshold" "$l_file"; then
			a_output+=(" - Remediation not needed: --terminated-pod-gc-threshold is present")
		else
			a_output2+=(" - Remediation Required: Please MANUALLY add '--terminated-pod-gc-threshold=10' (or similar) to $l_file")
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
