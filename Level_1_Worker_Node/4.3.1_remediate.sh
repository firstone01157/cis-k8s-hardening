#!/bin/bash
# CIS Benchmark: 4.3.1
# Title: Ensure that the kube-proxy metrics service is bound to localhost (Manual)
# Level: • Level 1 - Worker Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## Description from CSV:
	## Modify or remove any values which bind the metrics service to a non-localhost address
	##
	## Command hint: Modify or remove any values which bind the metrics service to a non-localhost address
	##
	## Safety Check: Verify if remediation is needed before applying

	a_output+=(" - Remediation: This is a manual check. Set --metrics-bind-address=127.0.0.1")
	return 0
}

remediate_rule
exit $?
