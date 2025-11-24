#!/bin/bash
# CIS Benchmark: 1.1.9
# Title: Ensure that the Container Network Interface file permissions are set to 600 or more restrictive (Manual)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this remediation command specifically
	## Description from CSV:
	## Run the below command (based on the file location on your system) on the Control Plane node. For example, chmod 600 <path/to/cni/files>
	##
	## Command hint: (based on the file location on your system) on the Control Plane node. For example, chmod 600 <path/to/cni/files>
	##
	## Safety Check: Verify if remediation is needed before applying
	## Placeholder logic (No-op by default until reviewed)
	## Change "1" to "0" once you implement the actual remediation

	l_cni_dir="/etc/cni/net.d"
	if [ -d "$l_cni_dir" ]; then
		while IFS= read -r l_file; do
			l_mode=$(stat -c %a "$l_file")
			if [ "$l_mode" -le 644 ]; then
				a_output+=(" - Remediation not needed: Permissions on $l_file are $l_mode")
			else
				chmod 644 "$l_file"
				l_mode_new=$(stat -c %a "$l_file")
				if [ "$l_mode_new" -le 644 ]; then
					a_output+=(" - Remediation applied: Permissions on $l_file changed to $l_mode_new")
				else
					a_output2+=(" - Remediation failed: Could not change permissions on $l_file")
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
