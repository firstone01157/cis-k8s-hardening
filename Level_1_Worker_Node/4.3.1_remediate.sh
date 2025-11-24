#!/bin/bash
# CIS Benchmark: 4.3.1
# Title: Ensure that the kube-proxy metrics service is bound to localhost (Manual)
# Level: • Level 1 - Worker Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	a_output+=(" - Remediation: Manual intervention required. Set '--metrics-bind-address=127.0.0.1' in kube-proxy flags.")
	return 0
}

remediate_rule
exit $?
