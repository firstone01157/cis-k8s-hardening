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

	## TODO: Verify this remediation command specifically
	## Description from CSV:
	## Edit the Controller Manager pod specification file /etc/kubernetes/manifests/kube- controller-manager.yaml on the Control Plane node to set the below parameter.  Internal Only - General --use-service-
	##
	## Command hint: Edit the Controller Manager pod specification file /etc/kubernetes/manifests/kube- controller-manager.yaml on the Control Plane node to set the below parameter.  Internal Only - General --use-service-account-credentials=true
	##
	## Safety Check: Verify if remediation is needed before applying
	## Placeholder logic (No-op by default until reviewed)
	## Change "1" to "0" once you implement the actual remediation

	l_file="/etc/kubernetes/manifests/kube-controller-manager.yaml"
	if [ -e "$l_file" ]; then
		if grep -q "\--use-service-account-credentials" "$l_file"; then
			# Ensure it is set to true
			sed -i 's/--use-service-account-credentials=[^ "]*/--use-service-account-credentials=true/g' "$l_file"
			a_output+=(" - Remediation applied: --use-service-account-credentials set to true in $l_file")
			return 0
		else
			# Default is false. Add it.
			a_output2+=(" - Remediation required: --use-service-account-credentials missing in $l_file. Please add '--use-service-account-credentials=true' manually.")
			return 1
		fi
	else
		a_output+=(" - Remediation not needed: $l_file not found")
		return 0
	fi
}

remediate_rule
exit $?
