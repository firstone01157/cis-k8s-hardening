#!/bin/bash
# CIS Benchmark: 2.3
# Title: Ensure that the --auto-tls argument is not set to true (Automated)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_file="/etc/kubernetes/manifests/etcd.yaml"
	if [ -e "$l_file" ]; then
		if grep -q "\--auto-tls=true" "$l_file"; then
			# Backup
			cp "$l_file" "$l_file.bak_$(date +%s)"
			# Remove it or set to false (default is false)
			sed -i 's/--auto-tls=true/--auto-tls=false/g' "$l_file"
			a_output+=(" - Remediation applied: --auto-tls set to false in $l_file")
			return 0
		else
			a_output+=(" - Remediation not needed: --auto-tls is not set to true in $l_file")
			return 0
		fi
	else
		a_output+=(" - Remediation not needed: $l_file not found")
		return 0
	fi
}

remediate_rule
exit $?
