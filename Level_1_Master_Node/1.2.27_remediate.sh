#!/bin/bash
# CIS Benchmark: 1.2.27
# Title: Ensure that the --encryption-provider-config argument is set as appropriate
# Level: Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# Manual intervention required for Encryption at Rest
	a_output+=(" - Remediation skipped: Manual configuration required for Encryption at Rest (1.2.27)")
	echo "Manual intervention required for 1.2.27"
	return 0
}

remediate_rule
exit $?