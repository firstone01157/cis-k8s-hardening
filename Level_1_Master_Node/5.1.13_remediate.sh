#!/bin/bash
# CIS Benchmark: 5.1.13
# Title: Minimize access to the service account token creation (Manual)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	a_output+=(" - Remediation: This is a manual check. Remove access to token sub-resource of serviceaccounts.")
	return 0
}

remediate_rule
exit $?
