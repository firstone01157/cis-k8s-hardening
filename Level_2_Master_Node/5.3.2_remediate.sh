#!/bin/bash
# CIS Benchmark: 5.3.2
# Title: Ensure that all Namespaces have Network Policies defined (Manual)
# Level: • Level 2 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	a_output+=(" - Remediation: Manual intervention required. Create NetworkPolicy objects for namespaces: $(kubectl get ns -o jsonpath='{.items[*].metadata.name}').")
	return 0
}

remediate_rule
exit $?
