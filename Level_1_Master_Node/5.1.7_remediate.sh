#!/bin/bash
# CIS Benchmark: 5.1.7
# Title: Avoid use of system:masters group (Manual)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	a_output+=(" - Remediation: This is a manual check. Remove system:masters group from users.")
	return 0
}

remediate_rule
exit $?
