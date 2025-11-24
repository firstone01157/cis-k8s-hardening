#!/bin/bash
# CIS Benchmark: 5.6.2
# Title: Ensure that the seccomp profile is set to docker/default in your pod definitions (Manual)
# Level: • Level 2 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	a_output+=(" - Remediation: Manual intervention required. Set 'securityContext.seccompProfile.type' to 'RuntimeDefault' in pod manifests.")
	return 0
}

remediate_rule
exit $?
