#!/bin/bash
# CIS Benchmark: 5.1.12
# Title: Minimize access to webhook configuration objects (Manual)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	a_output+=(" - Remediation: This is a manual check. Remove access to webhook configurations where possible.")
	return 0
}

remediate_rule
exit $?
