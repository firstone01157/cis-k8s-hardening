#!/bin/bash
# CIS Benchmark: 4.1.7
# Title: Ensure that the certificate authorities file permissions are set to 644 or more restrictive (Manual)
# Level: • Level 1 - Worker Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## Description from CSV:
	## Run the following command to modify the file permissions of the --client-ca-file chmod 644 <filename>
	##
	## Command hint: Run the following command to modify the file permissions of the --client-ca-file chmod 644 <filename>
	##
	## Safety Check: Verify if remediation is needed before applying

	client_ca_file=$(ps -ef | grep kubelet | grep -v grep | grep -o ' --client-ca-file=[^ ]*' | awk -F= '{print $2}')
	if [ -n "$client_ca_file" ] && [ -f "$client_ca_file" ]; then
		chmod 644 "$client_ca_file"
		a_output+=(" - Remediation applied: Set permissions of $client_ca_file to 644")
		return 0
	else
		a_output+=(" - Remediation skipped: --client-ca-file not set or file not found")
		return 0
	fi
}

remediate_rule
exit $?
