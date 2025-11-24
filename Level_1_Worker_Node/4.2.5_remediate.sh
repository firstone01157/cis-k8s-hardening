#!/bin/bash
# CIS Benchmark: 4.2.5
# Title: Ensure that the --streaming-connection-idle-timeout argument is not set to 0 (Manual)
# Level: • Level 1 - Worker Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	a_output+=(" - Remediation: Manual intervention required. Ensure '--streaming-connection-idle-timeout' is NOT set to 0. Default is 4h.")
	return 0
}

remediate_rule
exit $?
