#!/bin/bash
# CIS Benchmark: 1.2.13
# Title: Ensure that the admission control plugin NamespaceLifecycle is set (Automated)
# Level: • Level 2 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	file="/etc/kubernetes/manifests/kube-apiserver.yaml"
	if [ -f "$file" ]; then
		if grep -q "\--disable-admission-plugins" "$file" && grep -q "NamespaceLifecycle" "$file"; then
			cp "$file" "$file.bak_$(date +%s)"
			# Remove NamespaceLifecycle from the list
			sed -i -E 's/(--disable-admission-plugins=.*)NamespaceLifecycle,/\1/g' "$file"
			sed -i -E 's/(--disable-admission-plugins=.*),NamespaceLifecycle/\1/g' "$file"
			sed -i -E 's/(--disable-admission-plugins=.*)NamespaceLifecycle/\1/g' "$file"
			a_output+=(" - Remediation: Removed NamespaceLifecycle from --disable-admission-plugins in $file")
		else
			a_output+=(" - Remediation: NamespaceLifecycle not found in --disable-admission-plugins or flag not set")
		fi
	else
		a_output2+=(" - Remediation Failed: $file not found")
	fi
}

remediate_rule
exit $?
