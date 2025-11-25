#!/bin/bash
# CIS Benchmark: 1.2.30
# Title: Ensure that the --service-account-extend-token-expiration parameter is set to false (Automated)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_file="/etc/kubernetes/manifests/kube-apiserver.yaml"
	if [ -e "$l_file" ]; then
		if grep -q -- "--service-account-extend-token-expiration" "$l_file"; then
			if grep -q -- "--service-account-extend-token-expiration=false" "$l_file"; then
				a_output+=(" - Remediation not needed: --service-account-extend-token-expiration is already false")
			else
				cp "$l_file" "$l_file.bak_$(date +%s)"
				sed -i 's/--service-account-extend-token-expiration=[^ "]*\s*/--service-account-extend-token-expiration=false/g' "$l_file"
				a_output+=(" - Remediation applied: Set --service-account-extend-token-expiration to false")
			fi
		else
			a_output2+=(" - Remediation Required: Please MANUALLY add '--service-account-extend-token-expiration=false' to $l_file")
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
