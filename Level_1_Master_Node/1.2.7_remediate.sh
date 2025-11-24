#!/bin/bash
# CIS Benchmark: 1.2.7
# Title: Ensure that the --authorization-mode argument includes Node (Automated)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this remediation command specifically
	## Description from CSV:
	## Edit the API server pod specification file /etc/kubernetes/manifests/kube- apiserver.yaml on the Control Plane node and set the --authorization-mode parameter to a value that includes Node. --authoriz
	##
	## Command hint: Edit the API server pod specification file /etc/kubernetes/manifests/kube- apiserver.yaml on the Control Plane node and set the --authorization-mode parameter to a value that includes Node. --authorization-mode=Node,RBAC
	##
	## Safety Check: Verify if remediation is needed before applying
	## Placeholder logic (No-op by default until reviewed)
	## Change "1" to "0" once you implement the actual remediation

	l_file="/etc/kubernetes/manifests/kube-apiserver.yaml"
	if [ -e "$l_file" ]; then
		if grep -q "\--authorization-mode" "$l_file"; then
			if grep -q "Node" "$l_file"; then
				a_output+=(" - Remediation not needed: Node is present in --authorization-mode in $l_file")
				return 0
			else
				a_output2+=(" - Remediation required: Node missing from --authorization-mode in $l_file. Please add it manually.")
				return 1
			fi
		else
			a_output2+=(" - Remediation required: --authorization-mode flag is missing in $l_file. Please add it (e.g., Node,RBAC) manually.")
			return 1
		fi
	else
		a_output+=(" - Remediation not needed: $l_file not found")
		return 0
	fi
}

remediate_rule
exit $?
