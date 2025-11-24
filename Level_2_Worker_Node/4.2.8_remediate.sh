#!/bin/bash
# CIS Benchmark: 4.2.8
# Title: Ensure that the eventRecordQPS argument is set to a level which ensures appropriate event capture (Manual)
# Level: • Level 2 - Worker Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	config_file="/var/lib/kubelet/config.yaml"
	
	if [ -f "$config_file" ]; then
		if ! grep -q "eventRecordQPS" "$config_file"; then
			cp "$config_file" "$config_file.bak_$(date +%s)"
			# Add eventRecordQPS: 5 to the end of the file (simple append, might need better YAML handling but grep/sed is standard here)
			echo "eventRecordQPS: 5" >> "$config_file"
			a_output+=(" - Remediation: Added 'eventRecordQPS: 5' to $config_file")
			echo "Requires: systemctl daemon-reload && systemctl restart kubelet"
		else
			a_output+=(" - Remediation: eventRecordQPS already set in $config_file")
		fi
	else
		a_output2+=(" - Remediation Failed: $config_file not found")
	fi

	if [ "${#a_output2[@]}" -le 0 ]; then
		return 0
	else
		return 1
	fi
}

remediate_rule
exit $?
