#!/bin/bash
# CIS Benchmark: 1.3.7
# Title: Ensure that the --bind-address argument is set to 127.0.0.1 (Automated)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_file="/etc/kubernetes/manifests/kube-controller-manager.yaml"
	if [ -e "$l_file" ]; then
		if grep -q -- "--bind-address" "$l_file"; then
			if grep -q -- "--bind-address=127.0.0.1" "$l_file"; then
				a_output+=(" - Remediation not needed: --bind-address is already 127.0.0.1")
			else
				cp "$l_file" "$l_file.bak_$(date +%s)"
				sed -i 's/--bind-address=[^ "]*\s*/--bind-address=127.0.0.1/g' "$l_file"
				a_output+=(" - Remediation applied: Set --bind-address to 127.0.0.1")
			fi
		else
			a_output2+=(" - Remediation Required: Please MANUALLY add '--bind-address=127.0.0.1' to $l_file")
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
