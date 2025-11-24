#!/bin/bash
# CIS Benchmark: 5.6.4
# Title: The default namespace should not be used (Manual)
# Level: • Level 2 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	a_output+=(" - Remediation: Manual intervention required. Move resources from 'default' namespace to specific namespaces.")
	return 0
}

remediate_rule
exit $?
