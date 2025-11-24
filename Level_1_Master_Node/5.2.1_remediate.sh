#!/bin/bash
# CIS Benchmark: 5.2.1
# Title: Ensure that the cluster has at least one active policy control mechanism in place (Manual)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	a_output+=(" - Remediation: This is a manual check. Enable Pod Security Admission or other policy control.")
	return 0
}

remediate_rule
exit $?
