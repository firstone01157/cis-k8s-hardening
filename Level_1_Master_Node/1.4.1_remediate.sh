#!/bin/bash
# CIS Benchmark: 1.4.1
# Title: Ensure that the --profiling argument is set to false (Automated)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this remediation command specifically
	## Description from CSV:
	## Edit the Scheduler pod specification file /etc/kubernetes/manifests/kube- scheduler.yaml file on the Control Plane node and set the below parameter. --profiling=false
	##
	## Command hint: Edit the Scheduler pod specification file /etc/kubernetes/manifests/kube- scheduler.yaml file on the Control Plane node and set the below parameter. --profiling=false
	##
	## Safety Check: Verify if remediation is needed before applying
	## Placeholder logic (No-op by default until reviewed)
	## Change "1" to "0" once you implement the actual remediation

	l_file="/etc/kubernetes/manifests/kube-scheduler.yaml"
	if [ -e "$l_file" ]; then
		if grep -q "\--profiling" "$l_file"; then
			# Ensure it is set to false
			sed -i 's/--profiling=[^ "]*/--profiling=false/g' "$l_file"
			a_output+=(" - Remediation applied: --profiling set to false in $l_file")
			return 0
		else
			# Default is true. Add it.
			a_output2+=(" - Remediation required: --profiling missing in $l_file. Please add '--profiling=false' manually.")
			return 1
		fi
	else
		a_output+=(" - Remediation not needed: $l_file not found")
		return 0
	fi
}

remediate_rule
exit $?
