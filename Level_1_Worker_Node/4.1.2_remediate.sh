#!/bin/bash
# CIS Benchmark: 4.1.2
# Title: Ensure that the kubelet service file ownership is set to root:root
# Level: Level 1 - Worker Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# Check common locations for kubelet.service
	l_files=("/etc/systemd/system/kubelet.service" "/lib/systemd/system/kubelet.service")
	l_found=0
	l_failed=0

	for l_file in "${l_files[@]}"; do
		if [ -e "$l_file" ]; then
			l_found=1
			l_owner=$(stat -c "%U:%G" "$l_file")
			if [ "$l_owner" = "root:root" ]; then
				a_output+=(" - Remediation not needed: Ownership on $l_file is $l_owner")
			else
				cp -p "$l_file" "$l_file.bak.$(date +%s)"
				chown root:root "$l_file"
				l_owner_new=$(stat -c "%U:%G" "$l_file")
				if [ "$l_owner_new" = "root:root" ]; then
					a_output+=(" - Remediation applied: Ownership on $l_file changed to $l_owner_new")
				else
					a_output2+=(" - Remediation failed: Could not change ownership on $l_file")
					l_failed=1
				fi
			fi
		fi
	done

	if [ "$l_found" -eq 0 ]; then
		a_output+=(" - Remediation not needed: kubelet.service file not found in common locations")
		return 0
	elif [ "$l_failed" -eq 0 ]; then
		return 0
	else
		return 1
	fi
}

remediate_rule
exit $?
