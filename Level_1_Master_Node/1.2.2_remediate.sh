#!/bin/bash
# CIS Benchmark: 1.2.2
# Title: Ensure that the --token-auth-file parameter is not set (Automated)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_file="/etc/kubernetes/manifests/kube-apiserver.yaml"
	if [ -e "$l_file" ]; then
		if grep -q -- "--token-auth-file" "$l_file"; then
			cp "$l_file" "$l_file.bak_$(date +%s)"
			# Delete the line containing the flag
			sed -i '/--token-auth-file/d' "$l_file"
			a_output+=(" - Remediation applied: Removed --token-auth-file flag")
		else
			a_output+=(" - OK: --token-auth-file is not present")
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
