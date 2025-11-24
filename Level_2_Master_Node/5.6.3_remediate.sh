#!/bin/bash
# CIS Benchmark: 5.6.3
# Title: Apply Security Context to Your Pods and Containers (Manual)
# Level: • Level 2 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	a_output+=(" - Remediation: Manual intervention required. Apply appropriate security contexts (runAsUser, runAsGroup, fsGroup, etc.) to all pods.")
	return 0
}

remediate_rule
exit $?
