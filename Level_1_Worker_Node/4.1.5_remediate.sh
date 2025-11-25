#!/bin/bash
# CIS Benchmark: 4.1.5
# Title: Ensure that the --kubeconfig kubelet.conf file permissions are set to 600 or more restrictive (Automated)
# Level: • Level 1 - Worker Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## Description from CSV:
	## Run the below command (based on the file location on your system) on the each worker node. For example, chmod 600 /etc/kubernetes/kubelet.conf
	##
	## Command hint: (based on the file location on your system) on the each worker node. For example, chmod 600 /etc/kubernetes/kubelet.conf
	##
	## Safety Check: Verify if remediation is needed before applying

	kubelet_config=$(ps -ef | grep kubelet | grep -v grep | grep -o ' --kubeconfig=[^ ]*' | awk -F= '{print $2}')
	[ -z "$kubelet_config" ] && kubelet_config="/etc/kubernetes/kubelet.conf"

	if [ -f "$kubelet_config" ]; then
		chmod 600 "$kubelet_config"
		a_output+=(" - Remediation applied: Set permissions of $kubelet_config to 600")
		return 0
	else
		a_output+=(" - Remediation skipped: $kubelet_config does not exist")
		return 0
	fi
}

remediate_rule
exit $?
