#!/bin/bash
# CIS Benchmark: 1.2.9
# Title: Ensure that the admission control plugin EventRateLimit is set (Manual)
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
			if grep -q "EventRateLimit" "$l_file"; then
				a_output+=(" - Remediation not needed: EventRateLimit is present in $l_file")
			else
				cp "$l_file" "$l_file.bak_$(date +%s)"
				sed -i 's/\(--enable-admission-plugins=[^ ]*\)/\1,EventRateLimit/' "$l_file"
				a_output+=(" - Remediation applied: Appended EventRateLimit to --enable-admission-plugins")
			fi
		else
			a_output2+=(" - Remediation required: --enable-admission-plugins flag is missing in $l_file. Please add it with EventRateLimit manually.")
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
