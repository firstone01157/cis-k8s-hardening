#!/bin/bash
# CIS Benchmark: 1.2.14
# Title: Ensure that the --disable-admission-plugins argument is set to a value that does not include NamespaceLifecycle
# Level: Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_file="/etc/kubernetes/manifests/kube-apiserver.yaml"
	if [ -e "$l_file" ]; then
		if grep -q -- "--disable-admission-plugins" "$l_file"; then
			if grep -q -- "--disable-admission-plugins=.*NamespaceLifecycle" "$l_file"; then
				# Backup
				cp "$l_file" "$l_file.bak_$(date +%s)"
				
				# Remove NamespaceLifecycle
				sed -i 's/NamespaceLifecycle,//g' "$l_file"
				sed -i 's/,NamespaceLifecycle//g' "$l_file"
				sed -i 's/--disable-admission-plugins=NamespaceLifecycle//g' "$l_file"
				
				a_output+=(" - Remediation applied: Removed NamespaceLifecycle from --disable-admission-plugins in $l_file")
			fi
		fi
		return 0
	else
		return 0
	fi
}

remediate_rule
exit $?
