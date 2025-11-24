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

	## TODO: Verify this remediation command specifically
	## Description from CSV:
	## Edit the API server pod specification file /etc/kubernetes/manifests/kube- apiserver.yaml on the Control Plane node and set the below parameter. --service-account-lookup=true Alternatively, you can de
	##
	## Command hint: Edit the API server pod specification file /etc/kubernetes/manifests/kube- apiserver.yaml on the Control Plane node and set the below parameter. --service-account-lookup=true Alternatively, you can delete the --service-account-lookup parameter from this file so that the default takes effect.
	##
	## Safety Check: Verify if remediation is needed before applying
	## Placeholder logic (No-op by default until reviewed)
	## Change "1" to "0" once you implement the actual remediation

	l_file="/etc/kubernetes/manifests/kube-apiserver.yaml"
	if [ -e "$l_file" ]; then
		if grep -q "\--service-account-lookup" "$l_file"; then
			# Ensure it is set to true
			sed -i 's/--service-account-lookup=[^ "]*/--service-account-lookup=true/g' "$l_file"
			a_output+=(" - Remediation applied: --service-account-lookup set to true in $l_file")
			return 0
		else
			a_output2+=(" - Remediation required: --service-account-lookup flag is missing in $l_file. Please add '--service-account-lookup=true' manually.")
			return 1
		fi
	else
		a_output+=(" - Remediation not needed: $l_file not found")
		return 0
	fi
}

remediate_rule
exit $?
