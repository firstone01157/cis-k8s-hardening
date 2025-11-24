#!/bin/bash
# CIS Benchmark: 4.1.6
# Title: Ensure that the --kubeconfig kubelet.conf file ownership is set to root:root (Automated)
# Level: • Level 1 - Worker Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this remediation command specifically
	## Description from CSV:
	## Run the below command (based on the file location on your system) on the each worker node. For example, chown root:root /etc/kubernetes/kubelet.conf
	##
	## Command hint: (based on the file location on your system) on the each worker node. For example, chown root:root /etc/kubernetes/kubelet.conf
	##
	## Safety Check: Verify if remediation is needed before applying
	## Placeholder logic (No-op by default until reviewed)
	## Change "1" to "0" once you implement the actual remediation

	kubelet_config=$(ps -ef | grep kubelet | grep -v grep | grep -o ' --kubeconfig=[^ ]*' | awk -F= '{print $2}')
	[ -z "$kubelet_config" ] && kubelet_config="/etc/kubernetes/kubelet.conf"

	if [ -f "$kubelet_config" ]; then
		chown root:root "$kubelet_config"
		a_output+=(" - Remediation applied: Set ownership of $kubelet_config to root:root")
		return 0
	else
		a_output+=(" - Remediation skipped: $kubelet_config does not exist")
		return 0
	fi
}

remediate_rule
exit $?
