#!/bin/bash
# CIS Benchmark: 5.1.8
# Title: Limit use of the Bind, Impersonate and Escalate permissions in the Kubernetes cluster (Manual)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	a_output+=(" - Remediation: This is a manual check. Remove impersonate, bind, and escalate rights where possible.")
	return 0
}

remediate_rule
exit $?
