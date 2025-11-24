#!/bin/bash
# CIS Benchmark: 4.2.11
# Title: Verify that the RotateKubeletServerCertificate argument is set to true (Manual)
# Level: • Level 1 - Worker Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	a_output+=(" - Remediation: Manual intervention required. Enable 'serverTLSBootstrap: true' in kubelet config.")
	return 0
}

remediate_rule
exit $?
