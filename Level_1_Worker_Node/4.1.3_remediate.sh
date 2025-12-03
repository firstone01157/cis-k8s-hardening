#!/bin/bash
# CIS Benchmark: 4.1.3
# Title: If proxy kubeconfig file exists ensure permissions are set to 600 or more restrictive (Manual)
# Level: • Level 1 - Worker Node
# Remediation Script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/kubelet_helpers.sh"

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## Description from CSV:
	## Run the below command (based on the file location on your system) on the each worker node. For example, chmod 600 <proxy kubeconfig file>
	##
	## Command hint: (based on the file location on your system) on the each worker node. For example, chmod 600 <proxy kubeconfig file>
	##
	## Safety Check: Verify if remediation is needed before applying

	kube_proxy_kubeconfig=$(kube_proxy_kubeconfig_path)
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
