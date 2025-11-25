#!/bin/bash
# CIS Benchmark: 5.2.7
# Title: Minimize the admission of root containers (Manual)
# Level: • Level 2 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## Description from CSV:
	## Create a policy for each namespace in the cluster, ensuring that either MustRunAsNonRoot or MustRunAs with the range of UIDs not including 0, is set.
	##
	## Command hint: Create a policy for each namespace in the cluster, ensuring that either MustRunAsNonRoot or MustRunAs with the range of UIDs not including 0, is set.
	##
	## Safety Check: Verify if remediation is needed before applying

	a_output+=(" - Remediation: This is a manual check. Enforce runAsNonRoot: true in pods/policies.")
	return 0
}

remediate_rule
exit $?
