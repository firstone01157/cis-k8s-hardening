#!/bin/bash
# CIS Benchmark: 4.2.5
# Title: Ensure that the --streaming-connection-idle-timeout argument is not set to 0 (Manual)
# Level: • Level 1 - Worker Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## Description from CSV:
	## If using a Kubelet config file, edit the file to set streamingConnectionIdleTimeout to a value other than 0. If using command line arguments, edit the kubelet service file /etc/kubernetes/kubelet.conf
	##
	## Command hint: If using a Kubelet config file, edit the file to set streamingConnectionIdleTimeout to a value other than 0. If using command line arguments, edit the kubelet service file /etc/kubernetes/kubelet.conf on each worker node and set the below parameter in KUBELET_SYSTEM_PODS_ARGS variable. --streaming-connection-idle-timeout=5m Based on your system, restart the kubelet service. For example:  Internal Only - General systemctl daemon-reload systemctl restart kubelet.service
	##
	## Safety Check: Verify if remediation is needed before applying

	a_output+=(" - Remediation: Manual intervention required. Ensure '--streaming-connection-idle-timeout' is not set to 0.")
	return 0
}

remediate_rule
exit $?
