#!/bin/bash
# CIS Benchmark: 4.2.4
# Title: Verify that if defined, readOnlyPort is set to 0 (Manual)
# Level: • Level 1 - Worker Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	config_file="/var/lib/kubelet/config.yaml"
	if [ -f "$config_file" ]; then
		if ! grep -q "readOnlyPort" "$config_file"; then
			echo "readOnlyPort: 0" >> "$config_file"
			a_output+=(" - Remediation: Added 'readOnlyPort: 0' to $config_file")
			echo "Requires: systemctl daemon-reload && systemctl restart kubelet"
		else
			a_output+=(" - Remediation: readOnlyPort already present in $config_file. Please verify value is 0.")
		fi
	else
		a_output+=(" - Remediation: Manual intervention required. Set --read-only-port=0 in kubelet flags.")
	fi
	return 0
}

remediate_rule
exit $?
