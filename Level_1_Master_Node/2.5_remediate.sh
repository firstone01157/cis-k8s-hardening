#!/bin/bash
# CIS Benchmark: 2.5
# Title: Ensure that the --peer-client-cert-auth argument is set to true (Automated)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_file="/etc/kubernetes/manifests/etcd.yaml"
	if [ -e "$l_file" ]; then
		if grep -q "\--peer-client-cert-auth" "$l_file"; then
			if grep -q "\--peer-client-cert-auth=true" "$l_file"; then
				a_output+=(" - Remediation not needed: --peer-client-cert-auth is already true")
				return 0
			else
				# Change to true
				cp "$l_file" "$l_file.bak_$(date +%s)"
				sed -i 's/--peer-client-cert-auth=[^ "]*/--peer-client-cert-auth=true/g' "$l_file"
				a_output+=(" - Remediation applied: Set --peer-client-cert-auth to true in $l_file")
				return 0
			fi
		else
			a_output2+=(" - Remediation required: --peer-client-cert-auth missing in $l_file. Please add '--peer-client-cert-auth=true' manually.")
			return 1
		fi
	else
		a_output+=(" - Remediation not needed: $l_file not found")
		return 0
	fi
}

remediate_rule
exit $?
