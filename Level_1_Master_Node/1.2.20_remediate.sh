#!/bin/bash
# CIS Benchmark: 1.2.20
# Title: Ensure that the --request-timeout argument is set as appropriate (Manual)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this remediation command specifically
	## Description from CSV:
	## Edit the API server pod specification file /etc/kubernetes/manifests/kube- apiserver.yaml and set the below parameter as appropriate and if needed. For example, --request-timeout=300s
	##
	## Command hint: Edit the API server pod specification file /etc/kubernetes/manifests/kube- apiserver.yaml and set the below parameter as appropriate and if needed. For example, --request-timeout=300s
	##
	## Safety Check: Verify if remediation is needed before applying
	## Placeholder logic (No-op by default until reviewed)
	## Change "1" to "0" once you implement the actual remediation

	l_file="/etc/kubernetes/manifests/kube-apiserver.yaml"
	if [ -e "$l_file" ]; then
		if grep -q "\--request-timeout" "$l_file"; then
			a_output+=(" - Remediation not needed: --request-timeout is present in $l_file")
			return 0
		else
			# Default is 60s, which is fine.
			a_output+=(" - Remediation not needed: --request-timeout not set (defaults to 60s)")
			return 0
		fi
	else
		a_output+=(" - Remediation not needed: $l_file not found")
		return 0
	fi
}

remediate_rule
exit $?
