#!/bin/bash
# CIS Benchmark: 5.1.5
# Title: Ensure that default service accounts are not actively used. (Manual)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	a_output+=(" - Remediation: This is a manual check. Set automountServiceAccountToken: false for default service accounts.")
	return 0
}

remediate_rule
exit $?
