#!/bin/bash
# CIS Benchmark: 2.6
# Title: Ensure that the --peer-auto-tls argument is not set to true (Automated)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this remediation command specifically
	## Description from CSV:
	## Edit the etcd pod specification file /etc/kubernetes/manifests/etcd.yaml on the master node and either remove the --peer-auto-tls parameter or set it to false. --peer-auto-tls=false
	##
	## Command hint: Edit the etcd pod specification file /etc/kubernetes/manifests/etcd.yaml on the master node and either remove the --peer-auto-tls parameter or set it to false. --peer-auto-tls=false
	##
	## Safety Check: Verify if remediation is needed before applying
	## Placeholder logic (No-op by default until reviewed)
	## Change "1" to "0" once you implement the actual remediation

	l_file="/etc/kubernetes/manifests/etcd.yaml"
	if [ -e "$l_file" ]; then
		if grep -q "\--peer-auto-tls=true" "$l_file"; then
			# Remove it or set to false (default is false)
			sed -i 's/--peer-auto-tls=true/--peer-auto-tls=false/g' "$l_file"
			a_output+=(" - Remediation applied: --peer-auto-tls set to false in $l_file")
			return 0
		else
			a_output+=(" - Remediation not needed: --peer-auto-tls is not set to true in $l_file")
			return 0
		fi
	else
		a_output+=(" - Remediation not needed: $l_file not found")
		return 0
	fi
}

remediate_rule
exit $?
