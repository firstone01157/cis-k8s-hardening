#!/bin/bash
# CIS Benchmark: 1.2.14
# Title: Ensure that the admission control plugin NodeRestriction is set (Automated)
# Level: • Level 2 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	file="/etc/kubernetes/manifests/kube-apiserver.yaml"
	if [ -f "$file" ]; then
		if grep -q "\--enable-admission-plugins" "$file"; then
			if ! grep -q "NodeRestriction" "$file"; then
				cp "$file" "$file.bak_$(date +%s)"
				sed -i '/--enable-admission-plugins=/ s/$/,NodeRestriction/' "$file"
				a_output+=(" - Remediation: Added NodeRestriction to --enable-admission-plugins in $file")
			else
				a_output+=(" - Remediation: NodeRestriction already present")
			fi
		else
			a_output2+=(" - Remediation: --enable-admission-plugins flag not found. Please add '--enable-admission-plugins=NodeRestriction' manually.")
		fi
	else
		a_output2+=(" - Remediation Failed: $file not found")
	fi
}

remediate_rule
exit $?
