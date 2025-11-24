#!/bin/bash
# CIS Benchmark: 5.4.1
# Title: Prefer using secrets as files over secrets as environment variables (Manual)
# Level: • Level 2 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	a_output+=(" - Remediation: Manual intervention required. Modify application manifests to mount secrets as volumes instead of using 'env' with 'secretKeyRef'.")
	return 0
}

remediate_rule
exit $?
