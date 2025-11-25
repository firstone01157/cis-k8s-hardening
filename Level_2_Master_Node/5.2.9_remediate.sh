#!/bin/bash
# CIS Benchmark: 5.2.9
# Title: Minimize the admission of containers with capabilities assigned (Manual)
# Level: • Level 2 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## Description from CSV:
	## Review the use of capabilities in applications running on your cluster. Where a namespace contains applications which do not require any Linux capabilities to operate consider adding a policy which fo
	##
	## Command hint: Review the use of capabilities in applications running on your cluster. Where a namespace contains applications which do not require any Linux capabilities to operate consider adding a policy which forbids the admission of containers which do not drop all capabilities.
	##
	## Safety Check: Verify if remediation is needed before applying

	a_output+=(" - Remediation: This is a manual check. Drop unnecessary capabilities in pods/policies.")
	return 0
}

remediate_rule
exit $?
