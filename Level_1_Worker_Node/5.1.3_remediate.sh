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

	## Description from CSV:
	## Where possible replace any use of wildcards in ClusterRoles and Roles with specific objects or actions.
	##
	## Command hint: Where possible replace any use of wildcards in ClusterRoles and Roles with specific objects or actions.
	##
	## Safety Check: Verify if remediation is needed before applying

	a_output+=(" - Remediation: This is a manual check. Review and restrict wildcards in Roles/ClusterRoles.")
	return 0
}

remediate_rule
exit $?
