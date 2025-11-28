#!/bin/bash
# CIS Benchmark: 4.2.1
# Title: Ensure that the --anonymous-auth argument is set to false
# Level: Level 1 - Worker Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_file="/var/lib/kubelet/config.yaml"
	if [ -e "$l_file" ]; then
		# Backup
		cp "$l_file" "$l_file.bak_$(date +%s)"

		# Check if anonymous: enabled: true exists
		# We look for "anonymous:" followed by "enabled: true"
		# Use grep -A to check
		if grep -A 1 "anonymous:" "$l_file" | grep -q "enabled: true"; then
			# Attempt to replace
			# Use sed range or next line
			# sed -i '/anonymous:/,+1 s/enabled: true/enabled: false/' "$l_file"
			# Note: +1 address is a GNU sed extension. Standard sed might not support it.
			# But usually we are on Linux with GNU sed.
			
			sed -i '/anonymous:/,+1 s/enabled: true/enabled: false/' "$l_file"
			
			# Verify
			if grep -A 1 "anonymous:" "$l_file" | grep -q "enabled: false"; then
				a_output+=(" - Remediation applied: Set anonymous authentication to false in $l_file")
			else
				a_output2+=(" - Remediation failed: Could not update anonymous authentication in $l_file. Structure might be complex.")
				echo "Manual intervention required for 4.2.1"
			fi
		else
			# Check if it's already false
			if grep -A 1 "anonymous:" "$l_file" | grep -q "enabled: false"; then
				a_output+=(" - Remediation not needed: Anonymous authentication already disabled in $l_file")
			else
				# Maybe structure is different or missing
				a_output2+=(" - Remediation failed: Could not find 'anonymous: enabled: true' pattern in $l_file")
				echo "Manual intervention required for 4.2.1"
			fi
		fi
		
		echo "Action Required: Run 'systemctl daemon-reload && systemctl restart kubelet' to apply changes."
		return 0
	else
		a_output+=(" - Remediation not needed: $l_file not found")
		return 0
	fi
}

remediate_rule
exit $?
