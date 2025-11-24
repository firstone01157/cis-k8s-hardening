#!/bin/bash
# CIS Benchmark: 4.2.13
# Title: Ensure that a limit is set on pod PIDs (Manual)
# Level: • Level 1 - Worker Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	a_output+=(" - Remediation: Manual intervention required. Set 'podPidsLimit' in kubelet config.")
	return 0
}

remediate_rule
exit $?
