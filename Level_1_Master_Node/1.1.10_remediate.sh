#!/bin/bash
# CIS Benchmark: 1.1.10
# Title: Ensure that the Container Network Interface file ownership is set to root:root (Manual)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_cni_dir="/etc/cni/net.d"
	if [ -d "$l_cni_dir" ]; then
		while IFS= read -r l_file; do
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
		done < <(find "$l_cni_dir" -maxdepth 1 -type f)
	else
		a_output+=(" - Remediation not needed: $l_cni_dir not found")
	fi

	if [ "${#a_output2[@]}" -le 0 ]; then
		return 0
	else
		return 1
	fi
}

remediate_rule
exit $?
