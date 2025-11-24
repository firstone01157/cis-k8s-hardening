#!/bin/bash
# CIS Benchmark: 3.2.1
# Title: Ensure that a minimal audit policy is created (Manual)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	a_output+=(" - Remediation: This is a manual check. Please create an audit policy file and set --audit-policy-file in kube-apiserver.yaml.")
	return 0
}

remediate_rule
exit $?
