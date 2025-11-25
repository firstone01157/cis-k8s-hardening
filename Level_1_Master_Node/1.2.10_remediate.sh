#!/bin/bash
# CIS Benchmark: 1.2.10
# Title: Ensure that the admission control plugin AlwaysAdmit is not set (Automated)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_file="/etc/kubernetes/manifests/kube-apiserver.yaml"
	if [ -e "$l_file" ]; then
		if grep -q "\--enable-admission-plugins" "$l_file"; then
			if grep -q "AlwaysAdmit" "$l_file"; then
				a_output2+=(" - Remediation required: AlwaysAdmit present in --enable-admission-plugins in $l_file. Please remove it manually.")
				return 1
			else
				a_output+=(" - Remediation not needed: AlwaysAdmit not present in $l_file")
			fi
		else
			a_output+=(" - Remediation not needed: --enable-admission-plugins flag is missing")
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
