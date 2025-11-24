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

	## TODO: Verify this remediation command specifically
	## Description from CSV:
	## Run the below command (based on the file location on your system) on the each worker node. For example, chmod 600 <proxy kubeconfig file>
	##
	## Command hint: (based on the file location on your system) on the each worker node. For example, chmod 600 <proxy kubeconfig file>
	##
	## Safety Check: Verify if remediation is needed before applying
	## Placeholder logic (No-op by default until reviewed)
	## Change "1" to "0" once you implement the actual remediation

	kube_proxy_kubeconfig=$(ps -ef | grep kube-proxy | grep -v grep | grep -o ' --kubeconfig=[^ ]*' | awk -F= '{print $2}')
	if [ -n "$kube_proxy_kubeconfig" ] && [ -f "$kube_proxy_kubeconfig" ]; then
		chmod 600 "$kube_proxy_kubeconfig"
		a_output+=(" - Remediation applied: Set permissions of $kube_proxy_kubeconfig to 600")
		return 0
	else
		a_output+=(" - Remediation skipped: kube-proxy kubeconfig not found")
		return 0
	fi
}

remediate_rule
exit $?
