#!/bin/bash
# CIS Benchmark: 4.1.3
# Title: If proxy kubeconfig file exists ensure permissions are set to 600 or more restrictive (Manual)
# Level: • Level 1 - Worker Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	kube_proxy_kubeconfig=$(ps -ef | grep kube-proxy | grep -v grep | grep -o ' --kubeconfig=[^ ]*' | awk -F= '{print $2}')
	
	if [ -n "$kube_proxy_kubeconfig" ] && [ -f "$kube_proxy_kubeconfig" ]; then
		chmod 600 "$kube_proxy_kubeconfig"
		a_output+=(" - Remediation applied: Set permissions of $kube_proxy_kubeconfig to 600")
	else
		a_output+=(" - Remediation skipped: kube-proxy config not found or not running")
	fi
	return 0
}

remediate_rule
exit $?
