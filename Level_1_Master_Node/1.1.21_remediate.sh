#!/bin/bash
# CIS Benchmark: 1.1.21
# Title: Ensure that the Kubernetes PKI key file permissions are set to 600 (Manual)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this remediation command specifically
	## Description from CSV:
	## Run the below command (based on the file location on your system) on the Control Plane node. For example, chmod -R 600 /etc/kubernetes/pki/*.key
	##
	## Command hint: (based on the file location on your system) on the Control Plane node. For example, chmod -R 600 /etc/kubernetes/pki/*.key
	##
	## Safety Check: Verify if remediation is needed before applying
	## Placeholder logic (No-op by default until reviewed)
	## Change "1" to "0" once you implement the actual remediation

	l_dir="/etc/kubernetes/pki"
	if [ -d "$l_dir" ]; then
		l_remediated=0
		l_failed=0
		while IFS= read -r l_file; do
			l_mode=$(stat -c %a "$l_file")
			if [ "$l_mode" -le 600 ]; then
				: # OK
			else
				chmod 600 "$l_file"
				l_mode_new=$(stat -c %a "$l_file")
				if [ "$l_mode_new" -le 600 ]; then
					l_remediated=$((l_remediated + 1))
				else
					l_failed=$((l_failed + 1))
				fi
			fi
		done < <(find "$l_dir" -name "*.key" -type f)

		if [ "$l_failed" -gt 0 ]; then
			a_output2+=(" - Remediation failed: Could not change permissions on $l_failed .key files in $l_dir")
			return 1
		elif [ "$l_remediated" -gt 0 ]; then
			a_output+=(" - Remediation applied: Permissions changed on $l_remediated .key files in $l_dir")
			return 0
		else
			a_output+=(" - Remediation not needed: Permissions on .key files in $l_dir are correct")
			return 0
		fi
	else
		a_output+=(" - Remediation not needed: $l_dir not found")
		return 0
	fi
}

remediate_rule
exit $?
