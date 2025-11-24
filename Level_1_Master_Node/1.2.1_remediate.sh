#!/bin/bash
# CIS Benchmark: 1.2.1
# Title: Ensure that the --anonymous-auth argument is set to false (Manual)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_file="/etc/kubernetes/manifests/kube-apiserver.yaml"
	if [ -e "$l_file" ]; then
		# 1. Check if flag exists
		if grep -q -- "--anonymous-auth" "$l_file"; then
			# Check if already set to false
			if grep -q -- "--anonymous-auth=false" "$l_file"; then
				a_output+=(" - Remediation not needed: --anonymous-auth is already set to false")
			else
				# 2. Backup
				cp "$l_file" "$l_file.bak_$(date +%s)"
				# 3. Replace value using regex to catch current value
				sed -i 's/--anonymous-auth=[^ "]*\s*/--anonymous-auth=false/g' "$l_file"
				a_output+=(" - Remediation applied: Updated --anonymous-auth to false")
			fi
		else
			# 4. If missing, warn user (Safest approach)
			a_output2+=(" - Remediation Required: Please MANUALLY add '--anonymous-auth=false' to $l_file (under spec.containers.command)")
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
