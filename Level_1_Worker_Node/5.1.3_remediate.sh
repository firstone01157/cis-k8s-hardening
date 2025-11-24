#!/bin/bash
# CIS Benchmark: 5.1.3
# Title: Minimize wildcard use in Roles and ClusterRoles (Manual)
# Level: • Level 1 - Worker Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	a_output+=(" - Remediation: Manual intervention required. Review Roles and ClusterRoles to remove unnecessary wildcards ('*').")
	return 0
}

remediate_rule
exit $?
