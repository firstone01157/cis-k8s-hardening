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

	a_output+=(" - Remediation: Manual intervention required. Ensure containers drop ALL capabilities (securityContext.capabilities.drop: [\"ALL\"]).")
	return 0
}

remediate_rule
exit $?
