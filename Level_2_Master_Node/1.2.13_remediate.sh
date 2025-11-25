#!/bin/bash
# CIS Benchmark: 1.2.13
# Title: Ensure that the admission control plugin NamespaceLifecycle is set (Automated)
# Level: • Level 2 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## Description from CSV:
	## Edit the API server pod specification file /etc/kubernetes/manifests/kube- apiserver.yaml on the Control Plane node and set the --disable-admission- plugins parameter to ensure it does not include Nam
	##
	## Command hint: Edit the API server pod specification file /etc/kubernetes/manifests/kube- apiserver.yaml on the Control Plane node and set the --disable-admission- plugins parameter to ensure it does not include NamespaceLifecycle.
	##
	## Safety Check: Verify if remediation is needed before applying

	a_output+=(" - Remediation: Manual intervention required. Remove 'NamespaceLifecycle' from '--disable-admission-plugins' in /etc/kubernetes/manifests/kube-apiserver.yaml")
	return 0
}

remediate_rule
exit $?
