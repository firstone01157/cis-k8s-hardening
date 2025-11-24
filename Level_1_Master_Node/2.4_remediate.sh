#!/bin/bash
# CIS Benchmark: 2.4
# Title: Ensure that the --peer-cert-file and --peer-key-file arguments are set as appropriate (Automated)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this remediation command specifically
	## Description from CSV:
	## Follow the etcd service documentation and configure peer TLS encryption as appropriate for your etcd cluster. Then, edit the etcd pod specification file /etc/kubernetes/manifests/etcd.yaml on the mast
	##
	## Command hint: Follow the etcd service documentation and configure peer TLS encryption as appropriate for your etcd cluster. Then, edit the etcd pod specification file /etc/kubernetes/manifests/etcd.yaml on the master node and set the below parameters. --peer-client-file=</path/to/peer-cert-file> --peer-key-file=</path/to/peer-key-file>
	##
	## Safety Check: Verify if remediation is needed before applying
	## Placeholder logic (No-op by default until reviewed)
	## Change "1" to "0" once you implement the actual remediation

	l_file="/etc/kubernetes/manifests/etcd.yaml"
	if [ -e "$l_file" ]; then
		if grep -q "\--peer-cert-file" "$l_file" && grep -q "\--peer-key-file" "$l_file"; then
			a_output+=(" - Remediation not needed: etcd peer cert flags present in $l_file")
			return 0
		else
			a_output2+=(" - Remediation required: --peer-cert-file and/or --peer-key-file missing in $l_file. Please add them manually.")
			return 1
		fi
	else
		a_output+=(" - Remediation not needed: $l_file not found")
		return 0
	fi
}

remediate_rule
exit $?
