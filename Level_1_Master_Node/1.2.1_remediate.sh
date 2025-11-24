#!/bin/bash
# CIS Benchmark: 1.2.1
# Title: Ensure that the --anonymous-auth argument is set to false (Manual)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this remediation command specifically
	## Description from CSV:
	## Edit the API server pod specification file /etc/kubernetes/manifests/kube- apiserver.yaml on the Control Plane node and set the below parameter. --anonymous-auth=false
	##
	## Command hint: Edit the API server pod specification file /etc/kubernetes/manifests/kube- apiserver.yaml on the Control Plane node and set the below parameter. --anonymous-auth=false
	##
	## Safety Check: Verify if remediation is needed before applying
	## Placeholder logic (No-op by default until reviewed)
	## Change "1" to "0" once you implement the actual remediation

	l_file="/etc/kubernetes/manifests/kube-apiserver.yaml"
	if [ -e "$l_file" ]; then
		if grep -q "\--anonymous-auth" "$l_file"; then
			# Flag exists, update it
			sed -i 's/--anonymous-auth=[^ "]*/--anonymous-auth=false/g' "$l_file"
			a_output+=(" - Remediation applied: --anonymous-auth set to false in $l_file")
			return 0
		else
			# Flag missing, log warning
			a_output2+=(" - Remediation required: --anonymous-auth flag is missing in $l_file. Please add '--anonymous-auth=false' manually.")
			return 1
		fi
	else
		a_output+=(" - Remediation not needed: $l_file not found")
		return 0
	fi
}

remediate_rule
exit $?
