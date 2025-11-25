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

	a_output+=(" - Remediation: This is a manual check. Set eventRecordQPS in Kubelet config if required.")
	return 0
}

remediate_rule
exit $?
