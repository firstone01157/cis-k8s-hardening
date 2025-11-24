#!/bin/bash
# CIS Benchmark: 1.2.10
# Title: Ensure that the admission control plugin AlwaysAdmit is not set (Automated)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this remediation command specifically
	## Description from CSV:
	## Edit the API server pod specification file /etc/kubernetes/manifests/kube- apiserver.yaml on the Control Plane node and either remove the --enable- admission-plugins parameter, or set it to a value th
	##
	## Command hint: Edit the API server pod specification file /etc/kubernetes/manifests/kube- apiserver.yaml on the Control Plane node and either remove the --enable- admission-plugins parameter, or set it to a value that does not include AlwaysAdmit.
	##
	## Safety Check: Verify if remediation is needed before applying
	## Placeholder logic (No-op by default until reviewed)
	## Change "1" to "0" once you implement the actual remediation

	l_file="/etc/kubernetes/manifests/kube-apiserver.yaml"
	if [ -e "$l_file" ]; then
		if grep -q "\--enable-admission-plugins" "$l_file"; then
			if grep -q "AlwaysAdmit" "$l_file"; then
				a_output2+=(" - Remediation required: AlwaysAdmit present in --enable-admission-plugins in $l_file. Please remove it manually.")
				return 1
			else
				a_output+=(" - Remediation not needed: AlwaysAdmit not present in $l_file")
				return 0
			fi
		else
			a_output+=(" - Remediation not needed: --enable-admission-plugins flag is missing (so AlwaysAdmit is not enabled)")
			return 0
		fi
	else
		a_output+=(" - Remediation not needed: $l_file not found")
		return 0
	fi
}

remediate_rule
exit $?
