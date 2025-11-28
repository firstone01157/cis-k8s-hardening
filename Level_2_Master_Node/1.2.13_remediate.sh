#!/bin/bash
# CIS Benchmark: 1.2.13
# Title: Ensure that the --enable-admission-plugins argument includes SecurityContextDeny
# Level: Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_file="/etc/kubernetes/manifests/kube-apiserver.yaml"
	if [ -e "$l_file" ]; then
		# Backup
		cp "$l_file" "$l_file.bak_$(date +%s)"

		if grep -q -- "--enable-admission-plugins" "$l_file"; then
			if grep -q -- "--enable-admission-plugins=.*SecurityContextDeny" "$l_file"; then
				:
			else
				# Append
				sed -i 's/--enable-admission-plugins=[^ "]*/&,SecurityContextDeny/' "$l_file"
				a_output+=(" - Remediation applied: Appended SecurityContextDeny to --enable-admission-plugins in $l_file")
			fi
		else
			# Insert new
			sed -i "/- kube-apiserver/a \    - --enable-admission-plugins=SecurityContextDeny" "$l_file"
			a_output+=(" - Remediation applied: Inserted --enable-admission-plugins=SecurityContextDeny in $l_file")
		fi
		return 0
	else
		return 0
	fi
}

remediate_rule
exit $?
