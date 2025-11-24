#!/bin/bash
# CIS Benchmark: 1.3.3
# Title: Ensure that the --use-service-account-credentials argument is set to true (Automated)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_file="/etc/kubernetes/manifests/kube-controller-manager.yaml"
	if [ -e "$l_file" ]; then
		if grep -q -- "--use-service-account-credentials" "$l_file"; then
			if grep -q -- "--use-service-account-credentials=true" "$l_file"; then
				a_output+=(" - Remediation not needed: --use-service-account-credentials is already true")
			else
				cp "$l_file" "$l_file.bak_$(date +%s)"
				sed -i 's/--use-service-account-credentials=[^ "]*\s*/--use-service-account-credentials=true/g' "$l_file"
				a_output+=(" - Remediation applied: Set --use-service-account-credentials to true")
			fi
		else
			a_output2+=(" - Remediation Required: Please MANUALLY add '--use-service-account-credentials=true' to $l_file")
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
