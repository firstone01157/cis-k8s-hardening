#!/bin/bash
# CIS Benchmark: 5.1.2
# Title: Minimize access to secrets (Manual)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	a_output+=(" - Remediation: This is a manual check. Restrict access to secret objects where possible.")
	return 0
}

remediate_rule
exit $?
