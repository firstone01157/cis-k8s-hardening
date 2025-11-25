#!/bin/bash
# CIS Benchmark: 3.1.2
# Title: Service account token authentication should not be used for users (Manual)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	a_output+=(" - Remediation: This is a manual check. Please review user access and ensure service account token authentication is not used for users.")
	return 0
}

remediate_rule
exit $?
