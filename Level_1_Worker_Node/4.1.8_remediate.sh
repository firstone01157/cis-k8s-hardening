#!/bin/bash
# CIS Benchmark: 4.1.8
# Title: Ensure that the client certificate authorities file ownership is set to root:root (Manual)
# Level: • Level 1 - Worker Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## Description from CSV:
	## Run the following command to modify the ownership of the --client-ca-file. chown root:root <filename>
	##
	## Command hint: Run the following command to modify the ownership of the --client-ca-file. chown root:root <filename>
	##
	## Safety Check: Verify if remediation is needed before applying

	client_ca_file=$(ps -ef | grep kubelet | grep -v grep | grep -o ' --client-ca-file=[^ ]*' | awk -F= '{print $2}')
	if [ -n "$client_ca_file" ] && [ -f "$client_ca_file" ]; then
		chown root:root "$client_ca_file"
		a_output+=(" - Remediation applied: Set ownership of $client_ca_file to root:root")
		return 0
	else
		a_output+=(" - Remediation skipped: --client-ca-file not set or file not found")
		return 0
	fi
}

remediate_rule
exit $?
