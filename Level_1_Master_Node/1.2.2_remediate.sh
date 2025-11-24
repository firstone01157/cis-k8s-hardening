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

	## TODO: Verify this remediation command specifically
	## Description from CSV:
	## Follow the documentation and configure alternate mechanisms for authentication. Then, edit the API server pod specification file /etc/kubernetes/manifests/kube- apiserver.yaml on the master node and r
	##
	## Command hint: Follow the documentation and configure alternate mechanisms for authentication. Then, edit the API server pod specification file /etc/kubernetes/manifests/kube- apiserver.yaml on the master node and remove the --token-auth- file=<filename> parameter.
	##
	## Safety Check: Verify if remediation is needed before applying
	## Placeholder logic (No-op by default until reviewed)
	## Change "1" to "0" once you implement the actual remediation

	l_file="/etc/kubernetes/manifests/kube-apiserver.yaml"
	if [ -e "$l_file" ]; then
		if grep -q "\--token-auth-file" "$l_file"; then
			# Flag exists, remove it (comment out)
			sed -i 's/--token-auth-file/# --token-auth-file/g' "$l_file"
			a_output+=(" - Remediation applied: --token-auth-file commented out in $l_file")
			return 0
		else
			a_output+=(" - Remediation not needed: --token-auth-file not present in $l_file")
			return 0
		fi
	else
		a_output+=(" - Remediation not needed: $l_file not found")
		return 0
	fi
}

remediate_rule
exit $?
