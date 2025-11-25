#!/bin/bash
# CIS Benchmark: 4.2.6
# Title: Ensure that the --make-iptables-util-chains argument is set to true (Automated)
# Level: • Level 1 - Worker Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## Description from CSV:
	## If using a Kubelet config file, edit the file to set makeIPTablesUtilChains: true. If using command line arguments, edit the kubelet service file /etc/kubernetes/kubelet.conf on each worker node and r
	##
	## Command hint: If using a Kubelet config file, edit the file to set makeIPTablesUtilChains: true. If using command line arguments, edit the kubelet service file /etc/kubernetes/kubelet.conf on each worker node and remove the --make- iptables-util-chains argument from the KUBELET_SYSTEM_PODS_ARGS variable. Based on your system, restart the kubelet service. For example:  Internal Only - General systemctl daemon-reload systemctl restart kubelet.service
	##
	## Safety Check: Verify if remediation is needed before applying

	a_output+=(" - Remediation: Manual intervention required. Set '--make-iptables-util-chains=true' in kubelet config or startup flags.")
	return 0
}

remediate_rule
exit $?
