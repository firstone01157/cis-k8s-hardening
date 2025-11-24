#!/bin/bash
# CIS Benchmark: 5.5.1
# Title: Configure Image Provenance using ImagePolicyWebhook admission controller (Manual)
# Level: • Level 2 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	a_output+=(" - Remediation: Manual intervention required. Set up ImagePolicyWebhook in kube-apiserver if image provenance is required.")
	return 0
}

remediate_rule
exit $?
