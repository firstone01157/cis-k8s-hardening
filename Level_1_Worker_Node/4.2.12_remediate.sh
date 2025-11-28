#!/bin/bash
# CIS Benchmark: 4.2.12
# Title: Ensure that the --tls-cipher-suites argument is set to a strong value
# Level: Level 1 - Worker Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# Manual Warning Only
	a_output+=(" - Remediation skipped: Manual configuration required for TLSCipherSuites (4.2.12). Complex list configuration.")
	echo "Manual intervention required for 4.2.12"
	return 0
}

remediate_rule
exit $?
