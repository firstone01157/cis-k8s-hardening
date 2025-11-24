#!/bin/bash
# CIS Benchmark: 1.4.2
# Title: Ensure that the --bind-address argument is set to 127.0.0.1 (Automated)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this remediation command specifically
	## Description from CSV:
	## Edit the Scheduler pod specification file /etc/kubernetes/manifests/kube- scheduler.yaml on the Control Plane node and ensure the correct value for the -- bind-address parameter
	##
	## Command hint: Edit the Scheduler pod specification file /etc/kubernetes/manifests/kube- scheduler.yaml on the Control Plane node and ensure the correct value for the -- bind-address parameter
	##
	## Safety Check: Verify if remediation is needed before applying
	## Placeholder logic (No-op by default until reviewed)
	## Change "1" to "0" once you implement the actual remediation

	l_file="/etc/kubernetes/manifests/kube-scheduler.yaml"
	if [ -e "$l_file" ]; then
		if grep -q "\--bind-address" "$l_file"; then
			# Ensure it is set to 127.0.0.1
			sed -i 's/--bind-address=[^ "]*/--bind-address=127.0.0.1/g' "$l_file"
			a_output+=(" - Remediation applied: --bind-address set to 127.0.0.1 in $l_file")
			return 0
		else
			# Default is 0.0.0.0 (bad). Add it.
			a_output2+=(" - Remediation required: --bind-address missing in $l_file. Please add '--bind-address=127.0.0.1' manually.")
			return 1
		fi
	else
		a_output+=(" - Remediation not needed: $l_file not found")
		return 0
	fi
}

remediate_rule
exit $?
