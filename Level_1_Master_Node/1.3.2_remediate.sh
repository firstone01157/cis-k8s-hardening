#!/bin/bash
# CIS Benchmark: 1.3.2
# Title: Ensure that the --profiling argument is set to false (Automated)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_file="/etc/kubernetes/manifests/kube-controller-manager.yaml"
	if [ -e "$l_file" ]; then
		if grep -q -- "--profiling" "$l_file"; then
			if grep -q -- "--profiling=false" "$l_file"; then
				a_output+=(" - Remediation not needed: --profiling is already false")
			else
				cp "$l_file" "$l_file.bak_$(date +%s)"
				sed -i 's/--profiling=[^ "]*\s*/--profiling=false/g' "$l_file"
				a_output+=(" - Remediation applied: Set --profiling to false")
			fi
		else
			a_output2+=(" - Remediation Required: Please MANUALLY add '--profiling=false' to $l_file")
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
