#!/bin/bash
# CIS Benchmark: 1.2.3
# Title: Ensure that the DenyServiceExternalIPs is set (Manual)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this remediation command specifically
	## Description from CSV:
	## Edit the API server pod specification file /etc/kubernetes/manifests/kube- apiserver.yaml on the master node and append the Kubernetes API server flag -- enable-admission-plugins with the DenyServiceE
	##
	## Command hint: Edit the API server pod specification file /etc/kubernetes/manifests/kube- apiserver.yaml on the master node and append the Kubernetes API server flag -- enable-admission-plugins with the DenyServiceExternalIPs plugin. Note, the Kubernetes API server flag --enable-admission-plugins takes a comma-delimited list of admission control plugins to be enabled, even if they are in the list of plugins enabled by default. kube-apiserver --enable-admission-plugins=DenyServiceExternalIPs
	##
	## Safety Check: Verify if remediation is needed before applying
	## Placeholder logic (No-op by default until reviewed)
	## Change "1" to "0" once you implement the actual remediation

	l_file="/etc/kubernetes/manifests/kube-apiserver.yaml"
	if [ -e "$l_file" ]; then
		if grep -q "\--enable-admission-plugins" "$l_file"; then
			if grep -q "DenyServiceExternalIPs" "$l_file"; then
				a_output+=(" - Remediation not needed: DenyServiceExternalIPs is present in $l_file")
				return 0
			else
				# Complex edit, warn user
				a_output2+=(" - Remediation required: DenyServiceExternalIPs missing from --enable-admission-plugins in $l_file. Please add it manually.")
				return 1
			fi
		else
			a_output2+=(" - Remediation required: --enable-admission-plugins flag is missing in $l_file. Please add it with DenyServiceExternalIPs manually.")
			return 1
		fi
	else
		a_output+=(" - Remediation not needed: $l_file not found")
		return 0
	fi
}

remediate_rule
exit $?
