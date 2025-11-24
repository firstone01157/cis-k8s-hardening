#!/bin/bash
# CIS Benchmark: 1.1.14
# Title: Ensure that the default administrative credential file ownership is set to root:root (Automated)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	for l_file in "/etc/kubernetes/admin.conf" "/etc/kubernetes/super-admin.conf"; do
		if [ -e "$l_file" ]; then
			l_owner=$(stat -c %U:%G "$l_file")
			if [ "$l_owner" == "root:root" ]; then
				a_output+=(" - Remediation not needed: Ownership on $l_file is $l_owner")
			else
				chown root:root "$l_file"
				l_owner_new=$(stat -c %U:%G "$l_file")
				if [ "$l_owner_new" == "root:root" ]; then
					a_output+=(" - Remediation applied: Ownership on $l_file changed to $l_owner_new")
				else
					a_output2+=(" - Remediation failed: Could not change ownership on $l_file")
				fi
			fi
		else
			a_output+=(" - Remediation not needed: $l_file not found")
		fi
	done

	if [ "${#a_output2[@]}" -le 0 ]; then
		return 0
	else
		return 1
	fi
}

remediate_rule
exit $?
