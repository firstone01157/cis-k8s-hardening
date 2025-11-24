#!/bin/bash
# CIS Benchmark: 5.2.3
# Title: Minimize the admission of containers wishing to share the host process ID namespace (Manual)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	a_output+=(" - Remediation: This is a manual check. Add policies to restrict admission of hostPID containers.")
	return 0
}

remediate_rule
exit $?
