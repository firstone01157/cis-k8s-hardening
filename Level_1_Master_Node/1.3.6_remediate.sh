#!/bin/bash
# CIS Benchmark: 1.3.6
# Title: Ensure that the RotateKubeletServerCertificate argument is set to true (Automated)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_file="/etc/kubernetes/manifests/kube-controller-manager.yaml"
	if [ -e "$l_file" ]; then
		if grep -q "RotateKubeletServerCertificate=true" "$l_file"; then
			a_output+=(" - Remediation not needed: RotateKubeletServerCertificate=true is present")
		else
			# This is complex to append to existing feature gates safely via sed if we don't know if feature-gates exists.
			# If feature-gates exists, append. If not, warn.
			if grep -q "\--feature-gates" "$l_file"; then
				cp "$l_file" "$l_file.bak_$(date +%s)"
				sed -i 's/\(--feature-gates=[^ ]*\)/\1,RotateKubeletServerCertificate=true/' "$l_file"
				a_output+=(" - Remediation applied: Appended RotateKubeletServerCertificate=true to --feature-gates")
			else
				a_output2+=(" - Remediation Required: Please MANUALLY add '--feature-gates=RotateKubeletServerCertificate=true' to $l_file")
			fi
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
