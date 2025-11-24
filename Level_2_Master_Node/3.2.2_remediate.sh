#!/bin/bash
# CIS Benchmark: 3.2.2
# Title: Ensure that the audit policy covers key security concerns (Manual)
# Level: • Level 2 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	a_output+=(" - Remediation: Manual intervention required. Create/Update audit policy file and ensure --audit-policy-file is set in kube-apiserver.yaml. Requires volume mounts if file is new.")
	return 0
}

remediate_rule
exit $?
