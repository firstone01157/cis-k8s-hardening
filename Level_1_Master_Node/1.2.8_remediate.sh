#!/bin/bash
# CIS Benchmark: 1.2.8
# Title: Ensure that the --authorization-mode argument includes RBAC (Automated)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_file="/etc/kubernetes/manifests/kube-apiserver.yaml"
	if [ -e "$l_file" ]; then
		if grep -q "\--authorization-mode" "$l_file"; then
			if grep -q "RBAC" "$l_file"; then
				a_output+=(" - Remediation not needed: RBAC is present in --authorization-mode in $l_file")
			else
				cp "$l_file" "$l_file.bak_$(date +%s)"
				sed -i 's/\(--authorization-mode=[^ ]*\)/\1,RBAC/' "$l_file"
				a_output+=(" - Remediation applied: Appended RBAC to --authorization-mode")
			fi
		else
			a_output2+=(" - Remediation required: --authorization-mode flag is missing in $l_file. Please add it (e.g., Node,RBAC) manually.")
		fi
	else
		a_output+=(" - Remediation not needed: $l_file not found")
	fi

	if [ "${#a_output2[@]}" -le 0 ]; then
		return 0
	else
		return 1
	fi
}

remediate_rule
exit $?
