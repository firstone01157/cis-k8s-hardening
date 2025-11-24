#!/bin/bash
# CIS Benchmark: 5.6.1
# Title: Create administrative boundaries between resources using namespaces (Manual)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	a_output+=(" - Remediation: This is a manual check. Organize resources into namespaces.")
	return 0
}

remediate_rule
exit $?
