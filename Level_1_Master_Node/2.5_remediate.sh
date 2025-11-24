#!/bin/bash
# CIS Benchmark: 2.5
# Title: Ensure that the --peer-client-cert-auth argument is set to true (Automated)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this remediation command specifically
	## Description from CSV:
	## Edit the etcd pod specification file /etc/kubernetes/manifests/etcd.yaml on the master node and set the below parameter. --peer-client-cert-auth=true
	##
	## Command hint: Edit the etcd pod specification file /etc/kubernetes/manifests/etcd.yaml on the master node and set the below parameter. --peer-client-cert-auth=true
	##
	## Safety Check: Verify if remediation is needed before applying
	## Placeholder logic (No-op by default until reviewed)
	## Change "1" to "0" once you implement the actual remediation

	l_file="/etc/kubernetes/manifests/etcd.yaml"
	if [ -e "$l_file" ]; then
		if grep -q "\--peer-client-cert-auth" "$l_file"; then
			# Ensure it is set to true
			sed -i 's/--peer-client-cert-auth=[^ "]*/--peer-client-cert-auth=true/g' "$l_file"
			a_output+=(" - Remediation applied: --peer-client-cert-auth set to true in $l_file")
			return 0
		else
			# Default is false. Add it.
			a_output2+=(" - Remediation required: --peer-client-cert-auth missing in $l_file. Please add '--peer-client-cert-auth=true' manually.")
			return 1
		fi
	else
		a_output+=(" - Remediation not needed: $l_file not found")
		return 0
	fi
}

remediate_rule
exit $?
