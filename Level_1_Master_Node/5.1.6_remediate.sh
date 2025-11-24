#!/bin/bash
# CIS Benchmark: 5.1.6
# Title: Ensure that Service Account Tokens are only mounted where necessary (Manual)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	a_output+=(" - Remediation: This is a manual check. Set automountServiceAccountToken: false where appropriate.")
	return 0
}

remediate_rule
exit $?
