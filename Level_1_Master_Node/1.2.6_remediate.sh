#!/bin/bash
# CIS Benchmark: 1.2.6
# Title: Ensure that the --authorization-mode argument is not set to AlwaysAllow (Automated)
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
			if grep -q "AlwaysAllow" "$l_file"; then
				# AlwaysAllow is bad. We should set it to Node,RBAC (safe default)
				cp "$l_file" "$l_file.bak_$(date +%s)"
				sed -i 's/--authorization-mode=[^ "]*\s*/--authorization-mode=Node,RBAC/g' "$l_file"
				a_output+=(" - Remediation applied: Updated --authorization-mode to Node,RBAC")
			else
				a_output+=(" - Remediation not needed: AlwaysAllow not present in --authorization-mode in $l_file")
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
