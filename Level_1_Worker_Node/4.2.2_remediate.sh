#!/bin/bash
# CIS Benchmark: 4.2.2
# Title: Ensure that the --authorization-mode argument is set to Webhook
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

		# Check for authorization: mode: AlwaysAllow (default insecure)
		if grep -A 1 "authorization:" "$l_file" | grep -q "mode: AlwaysAllow"; then
			sed -i '/authorization:/,+1 s/mode: AlwaysAllow/mode: Webhook/' "$l_file"
			a_output+=(" - Remediation applied: Set authorization mode to Webhook in $l_file")
		elif grep -A 1 "authorization:" "$l_file" | grep -q "mode: Webhook"; then
			a_output+=(" - Remediation not needed: Authorization mode already Webhook in $l_file")
		else
			# Might be missing or different
			a_output2+=(" - Remediation failed: Could not find 'authorization: mode: AlwaysAllow' pattern in $l_file")
			echo "Manual intervention required for 4.2.2"
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
