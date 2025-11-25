#!/bin/bash
# CIS Benchmark: 1.2.10
# Title: Ensure that the admission control plugin AlwaysAdmit is not set (Automated)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_file="/etc/kubernetes/manifests/kube-apiserver.yaml"
	if [ -e "$l_file" ]; then
		if grep -q "\--enable-admission-plugins" "$l_file"; then
			if grep -q "AlwaysAdmit" "$l_file"; then
				cp "$l_file" "$l_file.bak_$(date +%s)"
				# Remove AlwaysAdmit from the comma separated list. 
				# Cases: 
				# 1. value,AlwaysAdmit,value
				# 2. value,AlwaysAdmit
				# 3. AlwaysAdmit,value
				# 4. AlwaysAdmit
				
				# Simplest sed approach: remove AlwaysAdmit and surrounding commas.
				sed -i 's/,AlwaysAdmit//g' "$l_file"
				sed -i 's/AlwaysAdmit,//g' "$l_file"
				sed -i 's/AlwaysAdmit//g' "$l_file"
				
				a_output+=(" - Remediation applied: Removed AlwaysAdmit from --enable-admission-plugins")
			else
				a_output+=(" - Remediation not needed: AlwaysAdmit not present in $l_file")
			fi
		else
			a_output+=(" - Remediation not needed: --enable-admission-plugins flag is missing")
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
