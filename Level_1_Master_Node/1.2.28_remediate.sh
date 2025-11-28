#!/bin/bash
# CIS Benchmark: 1.2.28
# Title: Ensure that the encryption provider is set to aescbc
# Level: Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# Manual intervention required for Encryption at Rest
	a_output+=(" - Remediation skipped: Manual configuration required for Encryption at Rest (1.2.28)")
	echo "Manual intervention required for 1.2.28"
	return 0
}

remediate_rule
exit $?