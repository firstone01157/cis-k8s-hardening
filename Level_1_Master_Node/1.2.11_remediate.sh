#!/bin/bash
# CIS Benchmark: 1.2.11
# Title: Ensure that the admission control plugin AlwaysPullImages is set (Manual)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this remediation command specifically
	## Description from CSV:
	## Edit the API server pod specification file /etc/kubernetes/manifests/kube- apiserver.yaml on the Control Plane node and set the --enable-admission- plugins parameter to include AlwaysPullImages. --ena
	##
	## Command hint: Edit the API server pod specification file /etc/kubernetes/manifests/kube- apiserver.yaml on the Control Plane node and set the --enable-admission- plugins parameter to include AlwaysPullImages. --enable-admission-plugins=...,AlwaysPullImages,...
	##
	## Safety Check: Verify if remediation is needed before applying
	## Placeholder logic (No-op by default until reviewed)
	## Change "1" to "0" once you implement the actual remediation

	l_file="/etc/kubernetes/manifests/kube-apiserver.yaml"
	if [ -e "$l_file" ]; then
		if grep -q "\--enable-admission-plugins" "$l_file"; then
			if grep -q "AlwaysPullImages" "$l_file"; then
				a_output+=(" - Remediation not needed: AlwaysPullImages is present in $l_file")
				return 0
			else
				a_output2+=(" - Remediation required: AlwaysPullImages missing from --enable-admission-plugins in $l_file. Please add it manually.")
				return 1
			fi
		else
			a_output2+=(" - Remediation required: --enable-admission-plugins flag is missing in $l_file. Please add it with AlwaysPullImages manually.")
			return 1
		fi
	else
		a_output+=(" - Remediation not needed: $l_file not found")
		return 0
	fi
}

remediate_rule
exit $?
