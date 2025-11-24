#!/bin/bash
# CIS Benchmark: 4.1.9
# Title: If the kubelet config.yaml configuration file is being used validate permissions set to 600 or more restrictive (Automated)
# Level: • Level 1 - Worker Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	kubelet_config_yaml=$(ps -ef | grep kubelet | grep -v grep | grep -o ' --config=[^ ]*' | awk -F= '{print $2}')
	[ -z "$kubelet_config_yaml" ] && kubelet_config_yaml="/var/lib/kubelet/config.yaml"

	if [ -f "$kubelet_config_yaml" ]; then
		chmod 600 "$kubelet_config_yaml"
		a_output+=(" - Remediation applied: Set permissions of $kubelet_config_yaml to 600")
	else
		a_output+=(" - Remediation skipped: $kubelet_config_yaml does not exist")
	fi
	return 0
}

remediate_rule
exit $?
