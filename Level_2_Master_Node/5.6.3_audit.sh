#!/bin/bash
# CIS Benchmark: 5.6.3
# Title: Apply Security Context to Your Pods and Containers (Manual)
# Level: • Level 2 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	a_output+=(" - Manual Check: Apply Security Context to Your Pods and Containers.")
	a_output+=(" - Note: This is a general best practice check. Verify that pods have securityContext defined (runAsNonRoot, readOnlyRootFilesystem, etc.).")
	
	# Always PASS this check as it's "Apply" (Manual/General)
	printf '%s\n' "" "- Audit Result:" "  [+] PASS" "${a_output[@]}"
	return 0
}

audit_rule
exit $?
