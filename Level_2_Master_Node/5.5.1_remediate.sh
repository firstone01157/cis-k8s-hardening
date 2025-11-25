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

	## Description from CSV:
	## Follow the Kubernetes documentation and setup image provenance.
	##
	## Command hint: Follow the Kubernetes documentation and setup image provenance.
	##
	## Safety Check: Verify if remediation is needed before applying

	a_output+=(" - Remediation: This is a manual check. Configure ImagePolicyWebhook.")
	return 0
}

remediate_rule
exit $?
