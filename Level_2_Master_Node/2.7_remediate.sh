#!/bin/bash
# CIS Benchmark: 2.7
# Title: Ensure that a unique Certificate Authority is used for etcd (Manual)
# Level: • Level 2 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	a_output+=(" - Remediation: Manual intervention required. You must generate a dedicated CA for etcd and update /etc/kubernetes/manifests/etcd.yaml to use it via --trusted-ca-file.")
	return 0
}

remediate_rule
exit $?
