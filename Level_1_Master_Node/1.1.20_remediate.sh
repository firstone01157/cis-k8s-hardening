#!/bin/bash
# CIS Benchmark: 1.1.20
# Title: Ensure that the Kubernetes PKI certificate file permissions are set to 644 or more restrictive (Manual)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_dir="/etc/kubernetes/pki"
	if [ -d "$l_dir" ]; then
		l_remediated=0
		l_failed=0
		while IFS= read -r l_file; do
			l_mode=$(stat -c %a "$l_file")
			if [ "$l_mode" -le 644 ]; then
				: # OK
			else
				chmod 644 "$l_file"
				l_mode_new=$(stat -c %a "$l_file")
				if [ "$l_mode_new" -le 644 ]; then
					l_remediated=$((l_remediated + 1))
				else
					l_failed=$((l_failed + 1))
				fi
			fi
		done < <(find "$l_dir" -name "*.crt" -type f)

		if [ "$l_failed" -gt 0 ]; then
			a_output2+=(" - Remediation failed: Could not change permissions on $l_failed .crt files in $l_dir")
			return 1
		elif [ "$l_remediated" -gt 0 ]; then
			a_output+=(" - Remediation applied: Permissions changed on $l_remediated .crt files in $l_dir")
			return 0
		else
			a_output+=(" - Remediation not needed: Permissions on .crt files in $l_dir are correct")
			return 0
		fi
	else
		a_output+=(" - Remediation not needed: $l_dir not found")
		return 0
	fi
}

remediate_rule
exit $?
