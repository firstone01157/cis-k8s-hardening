#!/bin/bash
# CIS Benchmark: 4.2.10
# Title: Ensure that the --rotate-certificates argument is not set to false (Automated)
# Level: • Level 1 - Worker Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## Description from CSV:
	## If using a Kubelet config file, edit the file to add the line rotateCertificates: true or remove it altogether to use the default value. If using command line arguments, edit the kubelet service file 
	##
	## Command hint: If using a Kubelet config file, edit the file to add the line rotateCertificates: true or remove it altogether to use the default value. If using command line arguments, edit the kubelet service file /etc/kubernetes/kubelet.conf on each worker node and remove --rotate- certificates=false argument from the KUBELET_CERTIFICATE_ARGS variable or set - -rotate-certificates=true .  Internal Only - General Based on your system, restart the kubelet service. For example: systemctl daemon-reload systemctl restart kubelet.service
	##
	## Safety Check: Verify if remediation is needed before applying

	a_output+=(" - Remediation: Manual intervention required. Ensure '--rotate-certificates' is not set to false.")
	return 0
}

remediate_rule
exit $?
