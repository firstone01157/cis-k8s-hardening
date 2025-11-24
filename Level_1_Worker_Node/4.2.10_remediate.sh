#!/bin/bash
# CIS Benchmark: 4.2.10
# Title: Ensure that the --rotate-certificates argument is not set to false (Automated)
# Level: • Level 1 - Worker Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	a_output+=(" - Remediation: Manual intervention required. Ensure 'rotateCertificates' is NOT set to false in kubelet config.")
	return 0
}

remediate_rule
exit $?
