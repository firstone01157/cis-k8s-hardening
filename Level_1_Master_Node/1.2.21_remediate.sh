#!/bin/bash
# CIS Benchmark: 1.2.21
# Title: Ensure that the --service-account-lookup argument is set to true (Automated)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_file="/etc/kubernetes/manifests/kube-apiserver.yaml"
	if [ -e "$l_file" ]; then
		if grep -q -- "--service-account-lookup=false" "$l_file"; then
			cp "$l_file" "$l_file.bak_$(date +%s)"
			# Update to true
			sed -i 's/--service-account-lookup=[^ "]*\s*/--service-account-lookup=true/g' "$l_file"
			a_output+=(" - Remediation applied: Updated --service-account-lookup to true")
		else
			a_output+=(" - Remediation not needed: --service-account-lookup is not set to false")
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
