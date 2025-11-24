#!/bin/bash
# CIS Benchmark: 5.3.1
# Title: Ensure that the CNI in use supports Network Policies (Manual)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	a_output+=(" - Remediation: This is a manual check. Install a CNI that supports Network Policies if not present.")
	return 0
}

remediate_rule
exit $?
