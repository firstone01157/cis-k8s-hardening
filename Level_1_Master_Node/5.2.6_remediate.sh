#!/bin/bash
# CIS Benchmark: 5.2.6
# Title: Minimize the admission of containers with allowPrivilegeEscalation (Manual)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	a_output+=(" - Remediation: This is a manual check. Set allowPrivilegeEscalation: false in pods where not required.")
	return 0
}

remediate_rule
exit $?
